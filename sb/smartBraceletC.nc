#include "smartBracelet.h"
#include "Timer.h"

module smartBraceletC{
	
	uses {
		interface Boot;
		interface Random;
		interface AMPacket;
		interface Packet as Packet;
		interface PacketAcknowledgements;
		interface AMSend as AMSend;
		interface SplitControl as ControlStandard;
		interface Receive;
		
		//interface for serial msg
		interface SplitControl as SerialControl; 
		interface Packet as SerialPacket;
		interface AMSend as AMSerial;
	
		//timer
		interface Timer<TMilli> as Timer0; //timer valido per l'accoppiamento
		interface Timer<TMilli> as Timer1; //timer per i messaggi del figlio
		interface Timer<TMilli> as Timer2; //timer di 60 secondi che scatta quando il padre non riceve informazioni del figlio
	}
}

implementation{

	uint8_t test = 0;

	//chiavi accoppiamento
	uint8_t myKey[RANDOMKEYLENGHT];
	uint8_t matchKey[RANDOMKEYLENGHT];
	
	//Contatori messaggi
	uint8_t counterBroad=0;
	uint8_t counterUni=0;
	uint8_t counterInfo=0;
	
	uint16_t matchAddress;
	bool coupled = FALSE;

	//Ultime coordinate del figlio mandate al padre
	uint16_t lastX;
	uint16_t lastY;
	
	//variabile per distinguere messaggi seriali di allarmi: 0 = caduto, 1 = perso
	bool infoAlarm;
	
	message_t packet;
	message_t packetSerial;
	

	//funzione invio messaggi broadcast
	task void sendBroadcast();
	task void sendChildMsg();
	task void sendUniCoupling();

	//funzioni per invio messaggi pericolo
	task void missingAlarm();
	task void fallAlarm();
	task void sendSerialMessage();

	

  

	//***************** Boot interface ********************//
	event void Boot.booted(){

	int i;
	
	dbg("boot", "Genero le chiavi casuali e le pre-carico nel nodo!.\n\n");		

		if (TOS_NODE_ID == 1){
		dbg("boot", "La chiave del nodo 1 e': ");
		for (i=0; i<RANDOMKEYLENGHT/2; i++){
			myKey[i] = 11;
			matchKey[i] = 21;
			dbg_clear("boot","%hhu", myKey[i]);
			}
		dbg_clear("boot","\n\n");
		} 
	
		if (TOS_NODE_ID == 2){
		dbg("boot", "La chiave del nodo 2 e': ");
		for (i=0; i<RANDOMKEYLENGHT/2; i++){
			myKey[i] = 21;
			matchKey[i] = 11;
			dbg_clear("boot","%hhu", myKey[i]);
			}
		dbg_clear("boot","\n\n");
		}

		if (TOS_NODE_ID == 3){
		dbg("boot", "La chiave del nodo 3 e': ");
		for (i=0; i<RANDOMKEYLENGHT/2; i++){
			myKey[i] = 12;
			matchKey[i] = 22;
			dbg_clear("boot","%hhu", myKey[i]);
			}
		dbg_clear("boot","\n\n");
		}
	
		if (TOS_NODE_ID == 4){
		dbg("boot", "La chiave del nodo 4 e': ");
		for (i=0; i<RANDOMKEYLENGHT/2; i++){
			myKey[i] = 22;
			matchKey[i] = 12;
			dbg_clear("boot","%hhu", myKey[i]);
			}
		dbg_clear("boot","\n\n");
		}

		dbg_clear("boot","\n\n\n");
		call ControlStandard.start();
	}
	
	//***************** SplitControl interface for mote to mote messages ********************//
	event void ControlStandard.startDone(error_t error){
		if(error == SUCCESS) {
			dbg("radio", "Avvio Timer0 al tempo %s che ogni 5 secondi invia un messaggio broadcast per richiedere accoppiamento\n\n", sim_time_string());
			call Timer0.startPeriodic(5000);
		}
		else{	
				dbgerror("radio","Errore accensione radio.\n\n");
			call ControlStandard.start();
		}
	}
	
	//***************** Timer for coulping interface ********************//
	event void Timer0.fired(){
		dbg("radio", "Timer0 scattato al tempo %s. Invio messaggio BROADCAST per accoppiamento.\n\n", sim_time_string());
		post sendBroadcast();
	}

	//***************** Timer1 interface for sending child msg ********************//
	event void Timer1.fired(){
		dbg("radio", "Timer1 scattato al tempo %s. Invio messaggio UNICAST con informazioni braccialetto figlio.\n\n", sim_time_string());
		post sendChildMsg();
	}

	//***************** Timer for allert message ********************//
	event void Timer2.fired(){
		dbg("radio", "Timer2 scattato al tempo %s. Non ricevo informazioni figlio da 60 secondi. Avviso il padre.\n\n", sim_time_string());
		post missingAlarm();
	}
	
	//***************** Task send messaggio in broadcast ********************//
	task void sendBroadcast() {
	int i;
		coupling_msg_t* mess=(coupling_msg_t*)(call Packet.getPayload(&packet,sizeof(coupling_msg_t)));
		
		//Inserisco chiave nel messaggio
		for (i=0; i<RANDOMKEYLENGHT/2; i++){
			mess->key[i]= myKey[i];
			}

		mess->address = TOS_NODE_ID; //gli do il mio indirizzo
		mess->type = BROADCAST; //mesasggio di tipo 1 = BROADCAST
		mess->id_b = counterBroad; //contatore dei messaggi
		counterBroad++;
	
		dbg("radio_send","Messaggio BROADCAST numero %hhu - Tempo: %s \n", mess->id_b,  sim_time_string());

		if(call AMSend.send(AM_BROADCAST_ADDR,&packet,sizeof(coupling_msg_t)) == SUCCESS){
	
			dbg_clear("radio_pack","Il messaggio BROADCAST numero %hhu e' stato inviato \n\n", mess->id_b );
			dbg_clear("radio_pack","\t\t Contenuto del messaggio broadcast: \n" );
			dbg_clear("radio_pack", "\t\t\t Chiave: ");
			for (i=0; i<RANDOMKEYLENGHT/2; i++){
				dbg_clear("radio_pack", "%hhu", mess->key[i]);
			}
			dbg_clear("radio_pack", "\n");
			dbg_clear("radio_pack", "\t\t\t Indirizzo: %hhu \n", mess->address);
			dbg_clear("radio_pack", "\t\t\t Tipo: %hhu \n", mess->type);
			dbg_clear("radio_pack", "\n\n");
 
		}
	}
	
	//***************** Task send unicast Coupling ********************//
	task void sendUniCoupling() {

		confirm_msg_t* mess=(confirm_msg_t*)(call Packet.getPayload(&packet,sizeof(confirm_msg_t)));
		mess->type = UNICAST;
		mess->id_u = counterUni;
		mess->confirm = 1; 

		dbg("radio_send", "Invio un messaggio in UNICAST al nodo %hhu al tempo %s per stoppare messaggi BROADCAST. Nodo trovato.\n\n", matchAddress, sim_time_string());

		call PacketAcknowledgements.requestAck( &packet );

		if(call AMSend.send(matchAddress,&packet,sizeof(confirm_msg_t)) == SUCCESS){
	
			dbg_clear("radio_pack","Il messaggio UNICAST numero %hhu e' stato inviato correttamente al nodo %hhu \n\n", mess->id_u, matchAddress );
			dbg_clear("radio_pack","\t\t Contenuto del messaggio unicast \n" );
			dbg_clear("radio_pack", "\t\t\t Contatore: %hhu \n ", mess->id_u);
			dbg_clear("radio_pack", "\t\t\t Tipo: %hhu \n", mess->type);
			dbg_clear("radio_pack", "\t\t\t Conferma: %hhu \n", mess->confirm);
			dbg_clear("radio_send", "\n\n ");
 
		}
	}
	
	//********************* AMSend (ricevo ack) interface ****************//
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

	event void ControlStandard.stopDone(error_t error){
		// not used
	}

	
	//********************* Receive interface (cosa avviene quando ricevo un msg) ****************//
	event message_t * Receive.receive(message_t *msg, void *payload, uint8_t len){
	
		coupling_msg_t* coupling_mess = (coupling_msg_t*)payload;
		confirm_msg_t* confirm_mess = (confirm_msg_t*)payload;
		info_msg_t* info_mess = (info_msg_t*)payload;
	
		bool eqKey = 1; //booleano per controllare che si stia ricevendo il messaggio dal nodo corretto
		int i;

		for (i=0; i<RANDOMKEYLENGHT/2; i++){
			if(coupling_mess->key[i]!= matchKey[i])
				eqKey = 0;
			}

		dbg("radio_rec", "Ho ricevuto un messaggio ");
		
		if ( coupling_mess->type == BROADCAST ) {
			dbg_clear("radio_rec", "di tipo BROADCAST.\n\n");
			
			
			if(eqKey){ //se le chiavi sono corrette (coincidono)
				dbg("radio_rec","Ho ricevuto richiesta di accoppiamento BROADCAST dal nodo corretto! Nodo: %hhu accoppiato con nodo: %hhu.\n Invio messaggio UNICAST per conferma.\n\n", TOS_NODE_ID, coupling_mess->address);
				matchAddress = coupling_mess->address;
				post sendUniCoupling();
			}else { 
				dbg("radio_rec", "Il messaggio BROADCAST ricevuto dal nodo %hhu non ha come mittente il nodo con il quale devo accoppiarmi.\n\n", coupling_mess->address); }
		}
	
		if ( confirm_mess ->type == UNICAST ) {
			dbg_clear("radio_rec", "di tipo UNICAST.\n\n");
			if (confirm_mess->confirm == 1){
				call Timer0.stop();
				dbg("radio_rec", "Non mando altri messaggi BROADCAST\n");
				coupled = TRUE;
				dbg("radio_rec", "Accoppiamento UNICAST effettuato\n\n");
	
				if((TOS_NODE_ID%2)==0){
					call Timer1.startPeriodic(10000);
				}
				if ((TOS_NODE_ID%2)!=0){
					call Timer2.startPeriodic(60000);
				}
			}
		}

		if(coupled==TRUE){
			if(info_mess-> type == INFO){
				dbg_clear("radio_rec", "informativo da mio figlio\n\n");
				dbg("radio_rec", "Contenuto messaggio:\n");
				dbg_clear("radio_rec", "\t\tLo stato del figlio è %hhu.\n", info_mess->state);
				dbg_clear("radio_rec", "\t\tCoordinata figlio (%hhu, %hhu).\n", info_mess->pos_x, info_mess->pos_y);
				// Memorizzo le ultime coordinate del figlio
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
	
	//***************** Task send child msg ********************//
	task void sendChildMsg() {
	
		info_msg_t* mess=(info_msg_t*)(call Packet.getPayload(&packet,sizeof(info_msg_t)));
	
		uint8_t msgStatus;
		uint16_t var = (call Random.rand16() % 10) + 1;

		dbg("radio", "Genero stato e coordinate da inviare a padre.\n");
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
		dbg("radio_send", "Pacchetto generato. Invio il messaggio al tempo %s.\n", sim_time_string());
	

		if(call AMSend.send(matchAddress,&packet,sizeof(info_msg_t)) == SUCCESS){
	
			dbg_clear("radio_pack","\t\t Contenuto del messaggio informativo: \n" );
			dbg_clear("radio_pack", "\t\t\t Tipo: %hhu \n ", mess->state);
			dbg_clear("radio_pack", "\t\t\t Coordinata X: %hhu \n", mess->pos_x);
			dbg_clear("radio_pack", "\t\t\t Coordinata Y: %hhu \n", mess->pos_y);
			dbg_clear("radio_send", "\n\n");
 
		}
	}
	
	//***************** Task bambino caduto ********************//
	task void fallAlarm(){ 
	dbg_clear("radio_pack", "\n\n");
			dbg("radio_pack", "ATTENZIONE! Il figlio e' caduto.\n\n");
			dbg_clear("radio_pack", "\n");
			infoAlarm = 0;
			call SerialControl.start();
			}

	//***************** Task informazioni non ricevute ********************//
	task void missingAlarm(){ 
			dbg_clear("radio_pack", "\n\n");
			dbg("radio_pack", "ATTENZIONE! Non ricevo informazioni da 60 secondi. L'ultima posizione rilevata e' (%hhu, %hhu)\n\n\n", lastX, lastY); 
			dbg_clear("radio_pack", "\n");
			infoAlarm = 1;
			call SerialControl.start();
			}
	
	
	//***************** Task send serial message ********************//	
	task void sendSerialMessage(){
    			
      			test_serial_msg_t* rcm = (test_serial_msg_t*)call SerialPacket.getPayload(&packetSerial, sizeof(test_serial_msg_t));
      			
      			if (rcm == NULL) {return;}
      			if (call SerialPacket.maxPayloadLength() < sizeof(test_serial_msg_t)) {return;}

      			rcm->sample_value = infoAlarm;
      			if (call AMSerial.send(TOS_NODE_ID, &packetSerial, sizeof(test_serial_msg_t)) == SUCCESS) {
				
				dbg("init","Invio un messaggio seriale\n\n");
      					}
    			}		
	
	//********************* AMSend (for serial msg) interface ****************//
	event void AMSerial.sendDone(message_t* bufPtr, error_t error) {
   		if (&packetSerial == bufPtr) {
    			}
 		}

	//***************** SplitControl interface for serial msg START*************//
 	event void SerialControl.startDone(error_t err) {
    		if (err == SUCCESS) {
      			post sendSerialMessage();
   			}
  		}	
  	
	//***************** SplitControl interface for serial msg STOP*************//
	event void SerialControl.stopDone(error_t err) {
		//not used	
		}
		
	
	
} //end of implementation
