#include "smartBracelet.h"
#include "Timer.h"

module smartBraceletC{
	
	uses {
		interface Boot;
		interface Random;
		interface AMPacket;
		interface Packet;
		interface PacketAcknowledgements;
		interface AMSend;
		interface SplitControl;
		interface Receive;
	
		//timer
		interface Timer<TMilli> as Timer0; //timer valido per l'accoppiamento
		interface Timer<TMilli> as Timer1; //timer per i messaggi del figlio
		interface Timer<TMilli> as Timer2; //timer di 60 secondi che scatta quando il padre non riceve informazioni del figlio
	}
}
implementation{

	uint8_t test = 0;

	//chiavi accoppiamento
	uint16_t myKey;
	uint16_t matchKey;
	
	//Contatori messaggi
	uint8_t counterBroad=0;
	uint8_t counterUni=0;
	uint8_t counterInfo=0;
	
	uint16_t matchAddress;
	bool coupled = FALSE;

	//Ultime coordinate del figlio mandate al padre
	uint16_t lastX;
	uint16_t lastY;
	
	message_t packet;

	//funzione invio messaggi broadcast
	task void sendBroadcast();
	task void sendChildMsg();
	task void sendUniCoupling();

	//funzioni per invio messaggi pericolo
	task void missingAlarm();
	task void fallAlarm();
	
	//funzione per generare lo status del figlio
	//async command uint8_t generateChildStatus();

	//***************** Boot interface ********************//
	event void Boot.booted(){
		if (TOS_NODE_ID == 1){
			myKey = 11;
			matchKey = 21;
		}
	
		if (TOS_NODE_ID == 2){
			myKey = 21;
			matchKey = 11;
		}

		if (TOS_NODE_ID == 3){
			myKey = 12;
			matchKey = 22;
		}
	
		if (TOS_NODE_ID == 4){
			myKey = 22;
			matchKey = 12;
		}

		call SplitControl.start();
	}
	
	//***************** SplitControl interface ********************//starta timer0
	event void SplitControl.startDone(error_t error){
		if(error == SUCCESS) {
			dbg("radio_send", " Avvio Timer0 al tempo %s che ogni 10 secondi invia un messaggio broadcast per richiedere accoppiamento\n", sim_time_string());
			call Timer0.startPeriodic(10000);
		}
		else{	
				dbg("role","Errore accensione radio.\n");
			call SplitControl.start();
		}
	}
	
	//***************** Timer for coulping interface ********************//
	event void Timer0.fired(){
		dbg("radio_send", "Timer0 scattato al tempo %s \n", sim_time_string());
		post sendBroadcast();
	}

	//***************** Timer for allert message ********************//
	event void Timer2.fired(){
		dbg("radio_send", "Timer2 scattato al tempo %s. Non ricevo informazioni figlio da 60 secondi. \n", sim_time_string());
		post missingAlarm();
	}
	
	//***************** Task send messaggio in broadcast ********************//
	task void sendBroadcast() {
		coupling_msg_t* mess=(coupling_msg_t*)(call Packet.getPayload(&packet,sizeof(coupling_msg_t)));
		mess->key = myKey; //gli do la chiave
		mess->address = TOS_NODE_ID; //gli do il mio indirizzo
		mess->type = BROADCAST; //mesasggio di tipo 1 = BROADCAST
		mess->id_b = counterBroad; //contatore dei messaggi
		counterBroad++;
	
		dbg_clear("radio_pack","Messaggio BROADCAST: %u - Tempo: %s \n", mess->id_b,  sim_time_string());
	
		//call PacketAcknowledgements.requestAck( &packet ); //chiamata richiesta ACK. Da NON mettere in BROADCAST

		if(call AMSend.send(AM_BROADCAST_ADDR,&packet,sizeof(coupling_msg_t)) == SUCCESS){
	
			dbg_clear("radio_pack","Il messaggio broadcast numero %hhu e' stato inviato \n", mess->id_b );
			dbg_clear("radio_pack","\t\t Contenuto del messaggio broadcast: \n" );
			dbg_clear("radio_pack", "\t\t Chiave: %hhu \n ", mess->key);
			dbg_clear("radio_pack", "\t\t Indirizzo: %hhu \n", mess->address);
			dbg_clear("radio_pack", "\t\t Tipo: %hhu \n", mess->type);
			dbg_clear("radio_send", "\n ");
			dbg_clear("radio_pack", "\n");
 
		}
	}
	
	//***************** Task send unicast Coupling ********************//
	task void sendUniCoupling() {

		confirm_msg_t* mess=(confirm_msg_t*)(call Packet.getPayload(&packet,sizeof(confirm_msg_t)));
		mess->type = UNICAST;
		mess->id_u = counterUni;
		mess->confirm = 1; //non dovrebbe servire in teoria

		dbg("radio_send", "Invio un messaggio in UNICAST al nodo %hhu per conferma accoppiamento al tempo %s \n", matchAddress, sim_time_string());
		dbg("radio_send", "Conferma: %hhu \n, tipo: %hhu, numero messaggio: %hhu\n", mess->confirm, mess->type, mess->id_u);

		call PacketAcknowledgements.requestAck( &packet );

		if(call AMSend.send(matchAddress,&packet,sizeof(confirm_msg_t)) == SUCCESS){
	
			dbg_clear("radio_pack","Il messaggio unicast numero %hhu al nodo %hhu e' stato inviato correttamente", mess->id_u, matchAddress );
			dbg_clear("radio_pack","\t\t Contenuto del messaggio unicast \n" );
			dbg_clear("radio_pack", "\t\t Contatore: %hhu \n ", mess->id_u);
			dbg_clear("radio_pack", "\t\t Tipo: %hhu \n", mess->type);
			dbg_clear("radio_send", "\n ");
			dbg_clear("radio_pack", "\n");
 
		}
	}
	
	//********************* AMSend (ricevo ack)) interface ****************//
	event void AMSend.sendDone(message_t *msg, error_t error){
	
		//	
		//		  if(&packet == msg && error == SUCCESS ) {
		//			dbg("radio_send", "Packet sent...");
		//
		//			if ( call PacketAcknowledgements.wasAcked( msg ) ) {
		//				dbg_clear("radio_ack", "and ack received");
		//				
		//			} else {
		//				dbg_clear("radio_ack", "but ack was not received");
		//			}
		//			dbg_clear("radio_send", " at time %s \n", sim_time_string());
		//		}	
	
	}

	event void SplitControl.stopDone(error_t error){
		// TODO Auto-generated method stub
	}

	
	//********************* Receive interface (cosa avviene quando ricevo un msg) ****************//
	event message_t * Receive.receive(message_t *msg, void *payload, uint8_t len){
	
		coupling_msg_t* coupling_mess = (coupling_msg_t*)payload;
		confirm_msg_t* confirm_mess = (confirm_msg_t*)payload;
		info_msg_t* info_mess = (info_msg_t*)payload;
		//dbg("radio_rec", "Ho ricevuto un messaggio.\n");
		//dbg("radio_rec", "Il tipo di messaggio ricevuto e': %hhu\n", coupling_mess->type);

		if ( coupling_mess->type == BROADCAST ) {
			//coupling_msg_t* coupling_mess = (coupling_msg_t*)payload;
			dbg("radio_rec", "Sono dentro al messaggio broadcast ricevuto.\n");
			if(coupling_mess->key == matchKey){
				dbg("radio_rec","Ho ricevuto richiesta di accoppiamento BROADCAST! Nodo: %hhu con chiave(myKey): %hhu. \nAccoppiato con Nodo: %hhu:  messKey: %hhu, \n Invio messaggio UNICAST per conferma.\n", TOS_NODE_ID, myKey, coupling_mess->address, coupling_mess->key  );
				matchAddress = coupling_mess->address;
				post sendUniCoupling();
			}else { dbg("radio_rec", "Il messaggio broadcast ricevuto dal nodo %hhu non ha come mittente il nodo con il quale devo accoppiarmi.\n", coupling_mess->address); }
		}
	
		if ( confirm_mess ->type == UNICAST ) {
			dbg("radio_rec", "Sono dentro al messaggio unicast\n");
			if (confirm_mess->confirm == 1){
				call Timer0.stop();
				dbg("radio_rec", "Ok, mi fermo nel mandare messaggi BROADCAST\n");
				coupled = TRUE;
				dbg("radio_rec", "Accoppiamento UNICAST effettuato\n");
	
				if((TOS_NODE_ID%2)==0){
					call Timer1.startPeriodic(10000);
				}
				if ((TOS_NODE_ID%2)!=0){
					call Timer2.startPeriodic(60000);
				}
			}
		}
		dbg("radio_rec", "coupled e': %hhu\n", coupled);
		if(coupled==TRUE){
			if(info_mess-> type == INFO){
				dbg("radio_rec", "Ho ricevuto il messaggio dal figlio\n");
				dbg("radio_rec", "Lo stato del figlio è %hhu.\n", info_mess->state);
				lastX = info_mess-> pos_x;
				lastY = info_mess-> pos_y;
				call Timer2.stop();
				call Timer2.startPeriodic(60000);
				if ((info_mess -> state) == FALLING) {
					post fallAlarm();
				}
			}
		}
		return msg;
	}
	
	//***************** Timer1 interface for sending child msg ********************//
	event void Timer1.fired(){
		dbg("radio_send", "Timer1 scattato al tempo %s \n", sim_time_string());
		post sendChildMsg();
	}
	
	
	//***************** Task send child msg ********************//
	task void sendChildMsg() {
	
		info_msg_t* mess=(info_msg_t*)(call Packet.getPayload(&packet,sizeof(info_msg_t)));
	
		uint8_t msgStatus;
		uint16_t var = (call Random.rand16() % 10) + 1;
		dbg_clear("radio_pack", "random: %hhu\n", var);
		switch (var) {
			case 1: 
			msgStatus = 11;
			break;
			case 2: 
			msgStatus = 11;
			break;
			case 3: 
			msgStatus = 11;
			break;
			case 4: 
			msgStatus = 12;
			break;
			case 5: 
			msgStatus = 12;
			break;
			case 6: 
			msgStatus = 12;
			break;
			case 7: 
			msgStatus = 13;
			break;
			case 8: 
			msgStatus = 13;
			break;
			case 9: 
			msgStatus = 13;
			break;
			case 10: 
			msgStatus = 14;
			break;
			default: 
			msgStatus = 10;
			break;
		} 
	
		//creo il messaggio
		mess->type = INFO; //mesasggio di tipo 3 = INFO
		mess->id_info = counterInfo; //contatore dei messaggi
		mess->pos_x = call Random.rand16();
		mess->pos_y = call Random.rand16();
		mess->state = msgStatus;
	
		counterInfo++;
		dbg("radio_send", "I'm the child, I'm sending a message\n");
		dbg_clear("radio_pack","Messaggio di info: %hhu - Tempo: %s \n", mess->id_info,  sim_time_string());
	

		if(call AMSend.send(matchAddress,&packet,sizeof(info_msg_t)) == SUCCESS){
	
			dbg_clear("radio_pack","\t\t Contenuto del messaggio info: \n" );
			dbg_clear("radio_pack", "\t\t Tipo: %hhu \n ", mess->state);
			dbg_clear("radio_pack", "\t\t Coordinata X: %hhu \n", mess->pos_x);
			dbg_clear("radio_pack", "\t\t Coordinata Y: %hhu \n", mess->pos_y);
			dbg_clear("radio_send", "\n ");
			dbg_clear("radio_pack", "\n");
 
		}
	}
	
	//***************** Task fall Allarm ********************//
	task void fallAlarm(){ 
		dbg_clear("radio_pack", "Sono in fallAlarm.\n"); 
	}
	
	//***************** Task missing Allarm ********************//
	task void missingAlarm(){ 
		dbg_clear("radio_pack", "Sono in missingAlarm\n"); 
	}
	
	
} //end of implementation