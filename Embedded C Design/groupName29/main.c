/*
 * Main file
 * Created: 15/08/2017 2:15:21 p.m.
 * Author : group29
 * Version 1: Testing code for Lab 2 Week 2
 * Version 2: Fix syntax and errors
 * Version 3: Minor alterations for testing phase 1
 * Version 4: Implemented ADC
 * Version 5: Implemented Linear approximation and instantaneous voltage
 * Version 6: Implemented interrupts and modified code for PCB
 * Version 7: Implemented Power calculations
 * Version 8: Finishing touches
 */


//Setup clock frequency
#define F_CPU 16000000 // Clock Speed

//Include library used
#include <stdio.h>
#include <stdbool.h>
#include <string.h>

#include <avr/io.h>
#include <avr/interrupt.h>
#include <util/delay.h>
#include "prototypes29.h"

 //Define Constants
 #define BAUD 9600
 #define MYUBRR F_CPU /16/BAUD-1
 #define N_SAMPLES 108

 //Shared variables for ISR
 volatile int indexVoltage = 0;
 volatile int indexCurrent = 0;
 volatile uint16_t adc_voltage[N_SAMPLES];
 volatile uint16_t adc_current[N_SAMPLES];
 volatile int transmitFlag = 0;

 //Interrupt to sample from one of the ADC channels
 ISR(ADC_vect){
	cli();	//Disables interrupts during this ISR

	//Samples a voltage reading from ADC0 channel
	if (((ADMUX & (1<<MUX0))==0) && ((ADMUX & (1<<MUX2))==0)) {
		adc_voltage[indexVoltage] = ADC;
		if (indexVoltage < N_SAMPLES) {
			indexVoltage++;
		} else {
			//When a set of samples has been complete, prepare for next set of sampling
			indexVoltage = 0;
		}
		//Change channel to ADC5
		ADMUX |= (1<<MUX2);
		ADMUX |= (1<<MUX0);
	}

	//Samples a voltage reading (of the shunt resistor) from ADC5 channel
	else if ((ADMUX & (1<<MUX0)) && (ADMUX & (1<<MUX2))) {
		adc_current[indexCurrent] = ADC;
		if (indexCurrent < N_SAMPLES) {
			indexCurrent++;
			
		} else {
			//When a set of samples has been complete, prepare for next set of sampling
			indexCurrent = 0;
			transmitFlag= 1; //When the desired number of samples of voltage and current are read, then raise the flag to transmit the values
		}
		//Change channel to ADC0
		ADMUX &= ~(1<<MUX2);
		ADMUX &= ~(1<<MUX0);
	}

	sei(); //Re-enables interrupts
	ADCSRA |= (1<<ADSC); //Start conversion for next sample
 }


int main(void)
{
	sei(); //Enable global interrupts
	//Initialize registers
	usart_init(MYUBRR);
	adc_init();

    while (1) {		
		//After desired number of samples of voltage and current(9 Waveforms), the voltage(RMS) and current(Peak) is transmitted to the CPLD
		if (transmitFlag==1) {
			cli();	//Disables interrupts so parameters can be calculated

			calcAndTransmit(adc_voltage, adc_current, sizeof(adc_voltage)/sizeof(adc_voltage[0]));

			_delay_ms(500); //Delay so display doesn't time out
			transmitFlag = 0;	//Resets flag and re-enables sampling so we can take another sample
			sei();	//Re-enable interrupts fro sampling again
		}
	}
}

