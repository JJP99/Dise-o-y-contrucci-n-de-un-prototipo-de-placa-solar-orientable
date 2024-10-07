/*
 * MotorEncoder.c
 *
 * Created: 27/03/2024 19:45:04
 * Author : Javi
 */ 

#include <avr/io.h>
#include <avr/interrupt.h>
#include <stdio.h>
#include "rs232atmega.h"

#define MYRS232BUFSIZE 32		//Tamaño buffer
#define MYRS232ENDCHAR '\r'		//Final de un comando
#define MYRS232SENDSIZE 128		//Tamaño maximo del comando enviado
#define MYRS232BAUDS 38400L		//Baudios

char rs232inputbuf[MYRS232BUFSIZE];		//Buffer de recepcion de datos
RS232InputReport rs232report;			//Informacion de los resultados
char rs232sentcommand[MYRS232SENDSIZE];	//Buffer de envio de datos

/* ------------------ Encoder ------------------ */

volatile int cnt_pulsos = 0;			//Contador de pulsos
volatile uint16_t pulsos_seg[100];		//Array de pulsos_seg. En cada posición se almacena el número de pulsos por segundo
volatile uint8_t indice_pulsos = 0;		//Indice en el array pulsos_seg
volatile uint8_t listoEnviar = 0;		//Cuando sea igual a 1 enviamos los datos del array de pulsos_seg por el puerto serie 
volatile uint8_t estado = 0;

void configEncoder(){
	//El encoder A esta en el Pin 2 -> PD2 -> INT0 -> PCINT18
	
	DDRD &= ~(0x01<<DDD2);	//Pin 2 configurado como entrada
	PORTD |= (0x01<<PORTD2); //Pull Up
	
	//Habilitar interrupciones externas
	EICRA |= (0x01<<ISC01) | (0x01<<ISC00); //Interrupciones en el flanco de subida
	
	EIMSK |= (0x01<<INT0); //Activar Interrupcion
	
}

ISR(INT0_vect){
	cnt_pulsos++;
}

/* ------------------ PWM ------------------ */

void configPWM(){
	//PWM de 100KHz, modo Phase Correct con Top=OCRA
	DDRD |= (0x01<<DDD5);  //Pin 5 configurado como Salida para la PWM
	TCCR0A |= (1<<COM0B1); //No Invertido
	TCCR0A |= (1<<WGM00);  //Phase Correct con TOP = OCRA
	TCCR0B |= (1<<WGM02);
}

void iniPWM(){
	//TCCR0B |= (1<<CS00);	//Sin preescalado
	OCR0A = 80;				//80 -> Para no llegar a 255 y tener una PWM de 100KHz
	OCR0B = 80;				//40 -> Duty 50%
}

void finPWM(){
	TCCR0B &=~ ((0x01<<CS02) | (0x01<<CS01) | (0x01<<CS00)); //Apagar PWM
}

/* ------------------ Timer ------------------ */

void configTimer1(){
	//Configuraciónn del Timer 1
	TCCR1B |= (0x01<<WGM12) | (0x01<<CS12);		//CTC con TOP = OCR1A + Preescalado = 256
	OCR1A = 6250;								//Periodo de 0.1s | 0.5 segundo = 31248s
	TIMSK1 |= (1 << OCIE1A);					//Habilitar flag de interrupcion por comparación con OCR1A
}

ISR(TIMER1_COMPA_vect){
	if(listoEnviar == 0){
		pulsos_seg[indice_pulsos] = cnt_pulsos;
		indice_pulsos++;
		//Inicialmente esta 1seg con el motor parado
		if (estado < 5*2 - 1){		//El timer es de 0,1s -> 5*2 = 10 -> 10*0.1 = 1
			finPWM();
			estado++;
		} else{						//Activamos la PWM para que el motor se mueva
			if (estado == 5*2 - 1)
				TCCR0B |= (1<<CS00);
			if(indice_pulsos >= 100){
				indice_pulsos = 0;
				listoEnviar = 1;
			}
		}
		cnt_pulsos=0;
	}
	
}

int main(void)
{
	cli();
	RS232_Init(rs232inputbuf,MYRS232BUFSIZE,MYRS232ENDCHAR,MYRS232BAUDS);
	configEncoder();
	configPWM();
	iniPWM();
	configTimer1();
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
	
	//Mover motor
	PORTD |= (0x01<<PORTD7);
	PORTB &= ~(0x01<<PORTD0);
	
    /* Replace with your application code */
    while (1) 
    {
		if(listoEnviar==1){
			for(uint8_t i = 0; i<100; i++){
				//snprintf(rs232sentcommand, MYRS232SENDSIZE, "Pulsos/seg: %d\r\n", pulsos_seg[i]);
				snprintf(rs232sentcommand, MYRS232SENDSIZE, "%d\r\n", pulsos_seg[i]);
				RS232_Send(rs232sentcommand, 0);
			}
			listoEnviar = 0;
		}
    }
}