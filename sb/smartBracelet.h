#ifndef SMART_BRACELET_H
#define SMART_BRACELET_H

#define RANDOMKEYLENGHT 20

//messaggio broadcast accoppiamento
typedef nx_struct coupling_msg{
	nx_uint8_t type;
	nx_uint8_t key[RANDOMKEYLENGHT];
	nx_uint16_t address;
	nx_uint8_t id_b;
}coupling_msg_t;

//messaggio conferma accoppiamento unicast
typedef nx_struct confirm_msg{
	nx_uint8_t type;
	nx_uint8_t confirm;
	nx_uint8_t id_u;
}confirm_msg_t;

//messaggio info braccialetto
typedef nx_struct info_msg{
	nx_uint8_t type;
	nx_uint16_t pos_x;
	nx_uint16_t pos_y;
	nx_uint8_t state;
	nx_uint16_t id_info;
} info_msg_t;

//messaggio seriale per tossimlive
typedef nx_struct test_serial_msg {
  	nx_uint16_t sample_value;
	} test_serial_msg_t;

//tipologia messaggi
#define BROADCAST 1
#define UNICAST 2
#define INFO 3

//info messaggi (azioni figlio)
#define STANDING 11
#define WALKING 12
#define RUNNING 13
#define FALLING 14



enum{
	AM_MY_MSG = 4,
	AM_TEST_SERIAL_MSG = 0x89,
};

#endif /* SMART_BRACELET_H */
