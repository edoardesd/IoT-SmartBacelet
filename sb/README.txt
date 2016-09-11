ISTRUZIONI
------------
CONTENUTO CARTELLA

### SmartBraceletAppC.nc, SmartBraceletC.nc, SmartBracelet.h ###
Contengono il programma TinyOS smart bracelet

### topology.txt, meyer-heavy.txt ###
Contengono i file per la configurazione della topologia dei braccialetti e il "noise trace" offerto dalla Meyer Library della Stanford University

### simulation.txt ###
Contiene il risultato dei messaggi dei braccialetti stampato su un file txt 

### TestSerial.java ###
Implementazione del programma che legge i messaggi dalla porta seriale

### run.py ###
Script di python che simula il comportamento di una coppia di braccialetti

------------
COME SI USA 

1. compilare il programma di TinyOS
	make micaz sim-sf
2. aprire il serial forwarder alla porta 9001
	java net.tinyos.sf.SerialForwarder -comm sf@localhost:9001&
3. runnare il programma java che accetta i messaggi provenienti dalla porta seriale 9002
	java TestSerial -comm sf@localhost:9002
4. runnare la simulazione dallo script di python
	python run.py
	
5. enjoy our work ;)




