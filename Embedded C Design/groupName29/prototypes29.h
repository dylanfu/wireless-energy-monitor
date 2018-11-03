void usart_init (uint16_t MYUBRR);
void usart_transmit (uint8_t data );
void adc_init ();
double adc_calculate (int adc_value);
double calculate_voltage (int adc_value);
double calculate_current (int adc_value);
int dp_index (double value);
void transmit_values(int parameter, double value);
void calcAndTransmit (volatile uint16_t vArray[], volatile uint16_t iArray[], uint16_t sizeOfArray);
