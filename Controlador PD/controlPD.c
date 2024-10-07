/*
 * controlP.c
 *
 * Created: 06/07/2024 19:54:26
 * Author : Javi
 */ 

#include <avr/io.h>
#include <avr/interrupt.h>
#include <stdlib.h>
#include <stdio.h>
#include "rs232atmega.h"


/* -------------- Constantes y Macros --------------- */ 

#define MYRS232BUFSIZE 32			//Tama�o buffer
#define MYRS232ENDCHAR '\r'			//Final de un comando
#define MYRS232SENDSIZE 128			//Tama�o maximo del comando enviado
#define MYRS232BAUDS 38400L			//Baudios
#define vRef 1.1					//Voltaje interno de 1.1V
#define Kp 50						//Ganancia proporcional | Original = 82.8
#define Kd 10						//Ganancia derivativa | Original = 200
#define TAM 200

char rs232inputbuf[MYRS232BUFSIZE];		//Buffer de recepcion de datos
RS232InputReport rs232report;			//Informacion de los resultados
char rs232sentcommand[MYRS232SENDSIZE];	//Buffer de envio de datos

const int16_t REFERENCIA = (0.3*1023)/1.1; //Voltaje referenc�a del sistema (lo convertimos en un valor digitial) -> 279
const double t_muestreo = 0.01;			   //Tiempo de muestreo

volatile uint16_t adc0_Valor = 0;    //Valor le�do del ADC0
volatile uint16_t adc1_Valor = 0;    //Valor le�do del ADC1
volatile int16_t U = 0;              //Se�al de control	-> U puede alcanzar valores que necesitan m�s de 8 bits para ser presentandados 
volatile int16_t error_anterior = 0; //Error en el muestreo anterior

volatile uint16_t vec_adc[TAM];		 //Array ADC
//volatile int16_t vec_U[TAM];		 //Array se�al de control con signo
volatile int16_t vec_error[TAM];	 //Array se�al de error
volatile double vec_errorD[TAM];	 //Array error derivada

volatile char listosEnviar = 0;		 //Enviar los datos por el puerto serie
volatile uint8_t indice = 0;		 //Indice del array


/* -------------- Funciones --------------- */ 

/* ADC */
void configADC(){	
	ADMUX = (0x01<<REFS1) | (0x01<<REFS0) | (0x01<<ADLAR); // Voltaje interno 1,1V y justificaci�n a la izquierda
	
	ADCSRA = (0x01<<ADEN) | (0x01<<ADPS2) | (0x01<<ADPS1) | (0x01<<ADPS0); //Habilito ADC + divisor de reloj en 128
}

uint16_t leerADC(uint8_t canal){
	ADMUX &= 0xF0; //Limpiamos los bits de la seleccion de canal
	
	//Seleccionamos el canal (0 o 1)
	ADMUX |= canal;
	
	//Comenzamos la conversi�n
	ADCSRA |= (0x01<<ADSC); //Hacemos una OR (|) para solo poner un 1 en el bit que queremos en caso de que este a 0
	
	//Esperamos a que termine la conversi�n
	while(!(ADCSRA & (0x01<<ADIF))); //Eperamos que ADIF sea 1
	
	//Para limpiar el bit ADIF para la pr�xima conversi�n hay que escribir un uno l�gico
	ADCSRA |= (1<<ADIF);
	
	//El resultado esta almacenado en el registro ADCH y ADCL
	uint16_t adcValue = (ADCL>>6);
	adcValue |= (ADCH<<2);	//Valor de ADC de 10 bits -> Voltaje rango 0-1023

	return adcValue;
}


/* Motor */
void configPWM(){
	//PWM de 100KHz, modo Phase Correct con Top=OCRA
	DDRD |= (0x01<<DDD5);  //Pin 5 configurado como Salida para la PWM
	TCCR0A |= (1<<COM0B1); //No Invertido
	TCCR0A |= (1<<WGM00);  //Phase Correct con TOP = OCRA
	TCCR0B |= (1<<WGM02);
}

void iniPWM(){
	TCCR0B |= (1<<CS00);	//Sin preescalado
	OCR0A = 80;				//80 -> Para no llegar a 255 y tener una PWM de 100KHz
	OCR0B = 20;				//20 -> Duty 25% -> Voltaje 6.8V (Teorico 3V)
}

void finPWM(){
	TCCR0B &=~ ((0x01<<CS02) | (0x01<<CS01) | (0x01<<CS00)); //Apagar PWM
}


/* Timer_1 */
void configTimer1(){
	//Tiempo de muestreo -> Si o si al timer 1 que es de 16 bits
	TCCR1B |= (0x01<<WGM12) | (0x01<<CS12);		//CTC con TOP = OCR1A + Preescalado = 256
	OCR1A = 625;								//Periodo de 0.5s = 31250 | 0.1s = 6250 | 0.01s = 625
	TIMSK1 |= (1 << OCIE1A);					//Habilitar flag de interrupcion por comparaci�n con OCR1A
}


/* Auxiliares */
void sentido_giro(char adc){
	/*Dependiendo de que placa reciba m�s luz nos movemos en un sentido u otro*/
	if(adc == 0)
	{
		PORTD |= (0x01<<PORTD7);
		PORTB &= ~(0x01<<PORTD0);
	}else{
		PORTD &= ~(0x01<<PORTD7);
		PORTB |= (0x01<<PORTD0);
	}
}


/* -------------- Interrupciones --------------- */ 

/* ISR Timer_1 */
ISR(TIMER1_COMPA_vect){
	/*Tenemos un timer de 0.01s (tiempo de muestreo), cuando pasa ese tiempo se comprueba el estado de las placas de solares y se aplica el control*/
	
	if(listosEnviar == 0){

		int16_t error;			//Se�al de error
		double error_derivada;   //Derivada del error
	
		adc0_Valor = leerADC(0);
	
		error = (int16_t) adc0_Valor - (int16_t) REFERENCIA;
		//error derivada = 0 primera vez y cuando se retome despues de enviar por rs232
		if(indice == 0)
		{
			error_derivada = 0;
		}else{
			error_derivada = (error - error_anterior)/t_muestreo;
		}
		error_anterior = error;
		
		U = (double)Kp * error + Kd * error_derivada;
		
		vec_adc[indice] = adc0_Valor;
		vec_error[indice] = error;
		vec_errorD[indice] = Kd*error_derivada;
		indice++;
		
		if(U < 0){
			sentido_giro(1);
		}else{
			sentido_giro(0);
		}
	
		//Ajustar la se�al de control para el motor
		//Limitar U para que est� en el rango del PWM (0 a 60), no llego a 80 por la no linealidad de saturacion 
		U = U < 0 ? -U : U;
		if (U > 60) U = 60;
		
		OCR0B = (uint8_t) U; //Ajustar el duty cycle del PWM
	
		if(indice >= TAM)
		{
			listosEnviar = 1;
			indice = 0;
			OCR0B = 0; //Paramos el motor mientras se envian los datos por el puerto serie 
		}			
	}
}


/* -------------- main --------------- */ 

int main(void)
{
	cli();
	configADC();
	configPWM();
	configTimer1();
	iniPWM();
	RS232_Init(rs232inputbuf,MYRS232BUFSIZE,MYRS232ENDCHAR,MYRS232BAUDS);
	sei();
	
	//Usamos el Pin 7 y el Pin 8 para controlar en el driver de motor los pines IN3 e IN4 respectivamente, con esto controlamos el sentido de giro del motor.
	DDRD |= (0x01<<DDD7); //Pin 7 de salida
	DDRB |= (0x01<<DDB0); //Pin 8 de salida
	
	/*Encendemos o apagamos los pines 7 y 8 para controlar el sentido de giro.
	
		7 - 8
		0 - 0 -> Apagado
		1 - 0 -> Izquierda
		0 - 1 -> Izquierda
		1 - 1 -> CORTOCIRCUITO
	*/
	
	char cREF[10];
	char cADC[16];
	char cError[16];
	char cErrorD[16]; //Este dato ya viene multiplicado por Kd	
	char cKp[16];
	
	//Mandamos el valor de referencia por el puerto serie una vez.
	snprintf(cREF, sizeof(cREF), "%d", REFERENCIA);
	snprintf(rs232sentcommand, MYRS232SENDSIZE, "%s\r\n", cREF);
	RS232_Send(rs232sentcommand, 0);
	
	dtostrf(Kp, 1, 2, cKp);
	snprintf(rs232sentcommand, MYRS232SENDSIZE, "%s\r\n", cKp);
	RS232_Send(rs232sentcommand, 0);
	
    /* Replace with your application code */
    while (1) 
    {
		if(listosEnviar) {
			
			/*Enviar luz (ADC), error y errorD*/					
			for(volatile uint8_t i = 0; i<TAM; i++)
			{
				snprintf(cADC, sizeof(cADC), "%d", vec_adc[i]);
				snprintf(cError, sizeof(cError), "%d", vec_error[i]);
				dtostrf(vec_errorD[i], 1, 2, cErrorD);
				//snprintf(cErrorD, sizeof(cErrorD), "%d", vec_errorD[i]);
				
				snprintf(rs232sentcommand, MYRS232SENDSIZE, "%s %s %s\r\n", cADC, cError, cErrorD);
				RS232_Send(rs232sentcommand, 0);
			}
			
			//Ya se han enviado los datos
			listosEnviar = 0;
			//OCR0B = 20;		//Reanudamos el motor
			
			//Hay que hacer algo con el tema mantener el ultimo error -> Decimos empezar de cero (error_derivada = 0 cada vez que se empieza de nuevo)
		}
		
    }
	
	return 0;
}