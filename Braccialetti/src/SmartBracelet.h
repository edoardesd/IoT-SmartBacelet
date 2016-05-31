#ifndef SMART_BRACELET_H
#define SMART_BRACELET_H

typedef nx_struct coupling_msg{
	nx_uint16_t key;
	nx_uint16_t address;
}coupling_msg_t;

typedef nx_struct info_msg{
	nx_uint8_t pos_x;
	nx_uint8_t pos_y;
	nx_uint8_t state;
	nx_uint16_t msg_counter;
} info_msg_t;

#define STANDING 1
#define WALKING 2
#define RUNNING 3
#define FALLING 4

enum{
		AM_MY_MSG = 6,
};

#endif /* SMART_BRACELET_H */
