/*
 * placas.c
 *
 * Caracterización de las placas solares
 *
 * Created: 19/01/2024 12:45:31
 * Author : Javi
 */ 

#include <avr/io.h>
#include <avr/interrupt.h>
#include <stdlib.h>
#include <stdio.h>
#include "rs232atmega.h"

/* -------------- Constantes y Macros --------------- */ 

#define MYRS232BUFSIZE 32		//Tamaño buffer
#define MYRS232ENDCHAR '\r'		//Final de un comando
#define MYRS232SENDSIZE 128		//Tamaño maximo del comando enviado
#define MYRS232BAUDS 38400L		//Baudios
#define vRef 1.1				//Voltaje interno de 1.1V
//#define vRef 5				//Voltaje interno de 5V

char rs232inputbuf[MYRS232BUFSIZE];		//Buffer de recepcion de datos 
RS232InputReport rs232report;			//Informacion de los resultados 
char rs232sentcommand[MYRS232SENDSIZE];	//Buffer de envio de datos


volatile uint16_t valoresA0[250];	//Array para almacenar 100 valores
volatile uint8_t indice = 0;		//Indice del array
volatile uint8_t listosEnviar = 0;	//Cuando esta a 1 el array esta lleno y se puede enviar
uint16_t valorA0;

/* -------------- Funciones --------------- */ 
void configADC(){
	//Configuramos el A0 para leer valores analógicos
	
	ADMUX = (0x01<<REFS1) | (0x01<<REFS0) | (0x01<<ADLAR); // Voltaje interno 1,1V y justificación a la izquierda
	
	//ADMUX = (0x01<<REFS0) | (0x01<<ADLAR); // Voltaje interno 5V y justificación a la izquierda
	
	ADCSRA = (0x01<<ADEN) | (0x01<<ADPS2) | (0x01<<ADPS1) | (0x01<<ADPS0); //Habilito ADC + divisor de reloj en 128
}

uint16_t leerADC(uint8_t canal){
	ADMUX &= 0xF0; //Limpiamos los bits de la seleccion de canal
	
	//Seleccionamos el canal (0 o 1)
	ADMUX |= canal;
	
	//Comenzamos la conversión
	ADCSRA |= (0x01<<ADSC); //Hacemos una OR (|) para solo poner un 1 en el bit que queremos en caso de que este a 0 
	
	//Esperamos a que termine la conversión
	while(!(ADCSRA & (0x01<<ADIF))); //Eperamos que ADIF sea 1
	
	//Para limpiar el bit ADIF para la próxima conversión hay que escribir un uno lógico
	ADCSRA |= (1<<ADIF);
	
	//El resultado esta almacenado en el registro ADCH y ADCL
	uint16_t adcValue = (ADCL>>6);
	adcValue |= (ADCH<<2);	//Valor de ADC de 10 bits -> Voltaje rango 0-1023	
	//Equivalente a hacer adcValue = ADCL | (ADCH<<8) si ADLAR=0 

	return adcValue;
}

void configTimer1(){
	//Configurcion del Timer 1
	TCCR1B |= (0x01<<WGM12) | (0x01<<CS12);		//CTC con TOP = OCR1A + Preescalado = 256
	OCR1A = 31250;								//Periodo de 0.5s = 31250 | 0.1s = 6250 | 0.01s = 625
	TIMSK1 |= (1 << OCIE1A);					//Habilitar flag de interrupcion por comparación con OCR1A
	
}

/* -------------- Interrupcion --------------- */ 
ISR(TIMER1_COMPA_vect) {
	if(listosEnviar == 0){
		valorA0 = leerADC(0); //Leer el valor ADC para el PIN A0
		valoresA0[indice] = valorA0; //Escribir valor en el array
		indice++; //Incrementar indice
			
		if(indice>=250){
			indice = 0;
			listosEnviar = 1;
		}	
	}
}

/*---------------------------------------------------------------------------------------------------------------------------------------------------------------------------*/

int main(void)
{
	//Inicializar puerto serie
	cli(); //Deshabilitar interrupciones globales
	RS232_Init(rs232inputbuf,MYRS232BUFSIZE,MYRS232ENDCHAR,MYRS232BAUDS);
	configADC();
	configTimer1();
	sei(); //Habilitar interrupciones globales
	
	float voltajeA0;
	char vA0[10];

    while (1) 
    {	
		//Si hemos leido 250 valores enviar por puerto serie		
		if(listosEnviar){
			for(uint8_t i = 0; i<250; i++){
				voltajeA0 = (valoresA0[i] * vRef) / 1023.0;
				dtostrf(voltajeA0, 1, 6, vA0);
				//Enviar resultados del Voltaje por RS232
				snprintf(rs232sentcommand, MYRS232SENDSIZE, "%s\r\n", vA0);
				RS232_Send(rs232sentcommand, 0);
			}
			//Ya se han enviado los datos
			listosEnviar = 0;
		}
	}
	
	return 0;	
}