#ifndef SMART_BRACELET_H
#define SMART_BRACELET_H

//messaggio broadcast accoppiamento
typedef nx_struct coupling_msg{
	nx_uint8_t msg_type;
	nx_uint16_t key;
	nx_uint16_t address;
	nx_uint8_t msg_id_b;
}coupling_msg_t;

//messaggio conferma accoppiamento unicast
typedef nx_struct confirm_msg{
	nx_uint8_t msg_type;
	nx_uint8_t confirm;
	nx_uint8_t msg_id_u;
}confirm_msg_t;

//messaggio info braccialetto
typedef nx_struct info_msg{
	nx_uint8_t msg_type;
	nx_uint8_t pos_x;
	nx_uint8_t pos_y;
	nx_uint8_t state;
	nx_uint16_t msg_counter;
} info_msg_t;

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
	AM_MY_MSG = 6,
};

#endif /* SMART_BRACELET_H */
