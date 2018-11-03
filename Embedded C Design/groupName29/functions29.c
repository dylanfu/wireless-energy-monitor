#define F_CPU 16000000 // Clock Speed

#include <avr/io.h>
#include <stdio.h>
#include <math.h>
#include <util/delay.h>

//Setup registers for transmit
void usart_init(uint16_t MYUBRR){
	//Store UBBR
	UBRR0L = MYUBRR;
	UBRR0H = (MYUBRR >> 8);
	//Enable Transmitter
	UCSR0B |= (1<<TXEN0);
	//Enable Character Size
	UCSR0C |= (1 << UCSZ00) | (1 << UCSZ01);
}

//Transmit data to CPLD
void usart_transmit(uint8_t data ){
	 //Polls until registers are empty then load data
	while (!(UCSR0A & (1<<UDRE0)));  
	UDR0 = data; 
}

//Setup registers for ADC
void adc_init (){
	ADMUX |= (1<<REFS0);
			
	ADCSRA = (1<<ADEN) |	//Enable ADC
			(1<<ADPS2) |	//Prescaler
			(1<<ADPS1) |
			(1<<ADIE) |		//Enable ADC Interrupts
			(1<<ADSC);		//Start initial conversion
}


//Calculate voltage read by ADC
double adc_calculate (int adc_value){	
	double Vin = (double) adc_value * 5;
	Vin = Vin / 1024;
	return Vin;
}

//Calculate the voltage source
double calculate_voltage (int adc_value){
	return (adc_calculate(adc_value)-2.55)*10.15;
}

//Calculate the voltage of the shunt 
double calculate_current (int adc_value){
	return (adc_calculate(adc_value)-2.55)/(5.62/3);
}

// Calculate position of the decimal point
int dp_index(double value){
	int positionDp = 0;
	int number = (int)value;
	//Case for when value is 0
	if (number == 0) {
		return 3;
	} else {
		while (number!=0) {
			positionDp++;
			number/=10;
		}
		return 4-positionDp;
	}
}

// Transmit each digit separately and decimal point if needed
void transmit_values(int parameter, double value){
	int dp_value= dp_index (value);
	int number = value * pow(10,dp_value);

	//Capping the maximum value that can be displayed
	if(value > 999){
		number = 9999;
	}

	//Transmit each digit in a data frame
	int position = 0;
	while (number!=0){
		usart_transmit((number%10)+parameter+position); //parameter relates to bits7:6, position relates to bits 5:4
		number/=10;
		position+=16;	//Change position in data frame
	}
	//Transmit a zero if the number is less than 3sf
	if (((int)value ==0) && (position == 48)) {
		usart_transmit(parameter + position);
	}

	//Transmit a data frame representing the decimal point
	if (dp_value!= 0){
		usart_transmit(parameter + 15 + (dp_value*16));
	}

}

// Calculate vRMS, iPeak and average power. Transmits each parameter to CPLD.
void calcAndTransmit (volatile uint16_t vArray[], volatile uint16_t iArray[], uint16_t sizeOfArray) {

	//************************Linear approximation****************************//
	//For voltage
	double voltageArray[sizeOfArray*2 -1];
	for(int i=0; i < (sizeOfArray*2-2); i+=2) {
		voltageArray[i] = calculate_voltage(vArray[i/2]);											//Store sampled value in even elements
		voltageArray[i+1] = calculate_voltage(((double)vArray[i/2] + (double)vArray[i/2+1])/2.0);	//Stores approximated values in odd elements
	}
	voltageArray[sizeOfArray*2 -2] = calculate_voltage(vArray[sizeOfArray-1]);

	//For current
	double currentArray[sizeOfArray*2 -1];
	for(int i=0; i < (sizeOfArray*2-2); i+=2) {
		currentArray[i] = calculate_current(iArray[i/2]);											//Store sampled value in even elements
		currentArray[i+1] = calculate_current(((double)iArray[i/2] + (double)iArray[i/2+1])/2.0);	//Stores approximated values in odd elements
	}
	currentArray[sizeOfArray*2 -2] = calculate_current(iArray[sizeOfArray-1]);

	//*************************************************************************//
	


	//Calculates voltage(RMS) from sampled and approximated points
	double totalVoltageSquared=0;
	for(int i=0; i < sizeOfArray*2 -1 ; i++) {
		totalVoltageSquared += (voltageArray[i] *voltageArray[i]);
	}
	double vRMS = sqrt((totalVoltageSquared/(sizeOfArray*2-1)));

	transmit_values(64, vRMS);	//Transmit voltage

	//Calculates current(Peak) from sampled and approximated points
	double totalVShuntSquared=0;
	for(int i=0; i < sizeOfArray*2 -1 ; i++) {
		totalVShuntSquared += (currentArray[i] *currentArray[i]);
	}
	double iPeak = sqrt((totalVShuntSquared/(sizeOfArray*2-1)))*sqrt(2);

	transmit_values(128, iPeak);	//Transmit current

	//***********************Trapezoidal approximation**************************//
	//Calculates power from voltage and current
	double totalPower=0;
	for(int i=0; i < sizeOfArray*2 -1 ; i++) {
		totalPower += (voltageArray[i] *currentArray[i]);
	}
	double avePower = fabs(totalPower/(sizeOfArray*2 -1));
	transmit_values(192, avePower);	//Transmit Power
}