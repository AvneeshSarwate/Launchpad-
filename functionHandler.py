import OSC
import threading

class FunctionHandler:
	
	def __init__(self):
		self.superColliderClient = OSC.OSCClient()
		self.superColliderClient.connect( ('127.0.0.1', 57120) ) 

		self.superColliderServer = OSC.OSCServer(('127.0.0.1', 13371))
		self.serverThread = threading.Thread(target=self.superColliderServer.serve_forever)
		self.serverThread.daemon = False
		self.serverThread.start()

		self.superColliderServer.addMsgHandler("/algRequest", self.handleAlgRequest)

	#stuff = [addr, chanInd, bankNum, root, scale, loopString] 
	def handleAlgRequest(self, addr, tags, stuff, source):
		msg = OSC.OSCMessage()
		msg.setAddress("/algResponse")
		msg.append("yo got it")
		print "got from supercollider"
		self.superColliderClient.send(msg)


	def end(self):
		self.superColliderServer.close()


