/**
 * ..... TODO
 * 
 *
 *  
 */

#include "sendAck.h"
#include "smartBracelet.h"
#include "Timer.h"

module smartBraceletC {

	uses {
		interface Boot;
		interface AMPacket;
		interface Packet;
		interface PacketAcknowledgements;
		interface AMSend;
		interface SplitControl;
		interface Receive;
		interface Timer<TMilli> as MilliTimer;
		interface Read<uint16_t>;
	}

} implementation {

	uint8_t counter=0;
	uint8_t rec_id;
 
	//chiavi accoppiamento
	uint16_t myKey;
	uint16_t matchKey;
	bool coupled = FALSE;
 
	uint16_t matchAddress;
 
 
 
	message_t packet;

	task void sendBroadCoupling();
	task void sendResp();
	task void sendUniConfirm();
 
 
 

	//****************** Task send response *****************//
	task void sendResp() {
		call Read.read();
	}

	//***************** Boot interface ********************//
	event void Boot.booted() {
		if (TOS_NODE_ID == 1){
			dbg("boot","PADRE \n");
			myKey = 12;
			matchKey = 33;
			dbg("boot","Sono il padre. La mia chiave e': %hhu e quella di mio figlio e': %hhu \n", myKey, matchKey);
		}
	
		if (TOS_NODE_ID == 2){
			dbg("boot","FIGLIO \n");
			myKey = 33;
			matchKey = 12;
			dbg("boot","Sono il figlio. La mia chiave e': %hhu e quella di mio padre e': %hhu \n", myKey, matchKey);
		}
	
		dbg("boot","Application booted.\n");
		call SplitControl.start();
	
	}

	//***************** SplitControl interface ********************//usato per far partire e stoppare i componenti
	event void SplitControl.startDone(error_t err){
 
		if(err == SUCCESS) {
			dbg("radio","Radio on!\n");
			if ( coupled == FALSE ) { //se non sono accoppiati (coupled == FALSE) invio messaggio broadcast
				dbg("role","Inizio a mandare il messaggio in broadcast\n");
				call MilliTimer.startPeriodic( 5000 );
			}
		}
		else{
				call SplitControl.start();
		}

	}
 
	//**********************StopDone interface
	event void SplitControl.stopDone(error_t err){}

	//***************** MilliTimer interface ********************//
	event void MilliTimer.fired() {
		post sendBroadCoupling();
	}
 
 
	//***************** Task send broad Coupling ********************//
	task void sendBroadCoupling() {

		coupling_msg_t* mess=(coupling_msg_t*)(call Packet.getPayload(&packet,sizeof(coupling_msg_t)));
		mess->key = myKey;
		mess->address = TOS_NODE_ID;
 
		dbg("radio_send", "Try to send a BROADCAST MESSAGE at time %s \n", sim_time_string());
		dbg("radio_send", "key: %hhu, address: %hhu \n", mess->key, mess->address);
 
		call PacketAcknowledgements.requestAck( &packet );

		if(call AMSend.send(AM_BROADCAST_ADDR,&packet,sizeof(my_msg_t)) == SUCCESS){
	
			dbg_clear("radio_pack","\t Source: %hhu \n ", call AMPacket.source( &packet ) );
			dbg_clear("radio_pack","\t Destination: %hhu \n ", call AMPacket.destination( &packet ) );
			dbg_clear("radio_pack","\t Lunghezza msg BROADCAST: %hhu \n ", sizeof(coupling_msg_t) );
			dbg_clear("radio_pack","\t\t Payload \n" );
			dbg_clear("radio_pack", "\t\t Chiave: %hhu \n ", mess->key);
			dbg_clear("radio_pack", "\t\t Indirizzo: %hhu \n", mess->address);
			dbg_clear("radio_send", "\n ");
			dbg_clear("radio_pack", "\n");
 
		}

	}  
 
	//********************* AMSend interface ****************//
	event void AMSend.sendDone(message_t* buf,error_t err) {

		if(&packet == buf && err == SUCCESS ) {
			dbg("radio_send", "Packet sent...");

			if ( call PacketAcknowledgements.wasAcked( buf ) ) {
				dbg_clear("radio_ack", "and ack received");
				call MilliTimer.stop();
			} else {
				dbg_clear("radio_ack", "but ack was not received");
				post sendBroadCoupling();
			}
			dbg_clear("radio_send", " at time %s \n", sim_time_string());
		}

	}

	//***************************** Receive interface *****************//
	event message_t* Receive.receive(message_t* buf,void* payload, uint8_t len) {


		if (sizeof(buf) == 4){
	
			coupling_msg_t* mess=(coupling_msg_t*)payload;
			dbg("radio_rec", "Sono dentro al broadcast message: \n");

			if(mess->key == matchKey){
				dbg("radio_rec","Match avvenuto! Nodo: %hhu con chiave(myKey): %hhu. \nAccoppiato con Nodo: %hhu:  messKey: %hhu, \n", TOS_NODE_ID, myKey, mess->address, mess->key  );
				matchAddress = mess->address;
				post sendUniConfirm();
			}
		}
	
		dbg("radio_send", "test di size of: %huu \n", sizeof(buf));
		if (sizeof(buf) == 1){
	
			confirm_msg_t* mess=(confirm_msg_t*)payload;
	
			if(mess->confirm){
				coupled = TRUE;
			}
			dbg("radio_send", "Ora coupled e' a: %u\n", coupled);
		}

		return buf;

	}
 
	//************************* Read interface **********************//
	event void Read.readDone(error_t result, uint16_t data) {

		my_msg_t* mess=(my_msg_t*)(call Packet.getPayload(&packet,sizeof(my_msg_t)));
		mess->msg_type = RESP;
		mess->msg_id = rec_id;
		mess->value = data;
 
		dbg("radio_send", "Try to send a response to node 1 at time %s \n", sim_time_string());
		call PacketAcknowledgements.requestAck( &packet );
		if(call AMSend.send(1,&packet,sizeof(my_msg_t)) == SUCCESS){
	
			dbg("radio_send", "Packet passed to lower layer successfully!\n");
			dbg("radio_pack",">>>Pack\n \t Payload length %hhu \n", call Packet.payloadLength( &packet ) );
			dbg_clear("radio_pack","\t Source: %hhu \n ", call AMPacket.source( &packet ) );
			dbg_clear("radio_pack","\t Destination: %hhu \n ", call AMPacket.destination( &packet ) );
			dbg_clear("radio_pack","\t AM Type: %hhu \n ", call AMPacket.type( &packet ) );
			dbg_clear("radio_pack","\t\t Payload \n" );
			dbg_clear("radio_pack", "\t\t msg_type: %hhu \n ", mess->msg_type);
			dbg_clear("radio_pack", "\t\t msg_id: %hhu \n", mess->msg_id);
			dbg_clear("radio_pack", "\t\t value: %hhu \n", mess->value);
			dbg_clear("radio_pack", "\t\t jey: %hhu \n", myKey);
			dbg_clear("radio_send", "\n ");
			dbg_clear("radio_pack", "\n");

		}

	}


	//***************** Task send broad Coupling ********************//
	task void sendUniConfirm() {

		confirm_msg_t* mess=(confirm_msg_t*)(call Packet.getPayload(&packet,sizeof(confirm_msg_t)));
		mess->confirm = 1;
 
		dbg("radio_send", "Try to send a UNICAST MESSAGE at time %s \n", sim_time_string());
		dbg("radio_send", "Messaggio conferma: %hhu \n", mess->confirm);
 
		call PacketAcknowledgements.requestAck( &packet );

		if(call AMSend.send(matchAddress,&packet,sizeof(my_msg_t)) == SUCCESS){
	
			dbg_clear("radio_pack","\t Source: %hhu \n ", call AMPacket.source( &packet ) );
			dbg_clear("radio_pack","\t Destination: %hhu \n ", call AMPacket.destination( &packet ) );
			dbg_clear("radio_pack","\t Lunghezza UNI: %hhu \n ", sizeof(confirm_msg_t) );
			dbg_clear("radio_pack","\t\t Payload \n" );
			dbg_clear("radio_pack", "\t\t Conferma: %hhu \n ", mess->confirm);
			dbg_clear("radio_send", "\n ");
			dbg_clear("radio_pack", "\n");
 
		}

	} 


}

