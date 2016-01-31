(
var launchpadOut, padTL, padBL, padTR, padBR, colorBL1, colorBR1, colorTL1, colorTR1, colorBL2, colorBR2, colorTL2, colorTR2, colorON, pads, padMap, madePadList, scales, roots, padOn, padOff, setPadLights, transposes, makePadList, indToNote_, indToNote, midiOut, launchPad, tempoClock, interruptLoopButtons, controlChanInd, tapTempoSetButton, tapTempoToggle, recordButton, lastTap, playMetronome, recordingMetronome, metronomeFunc, preRecordCount, preRecordLength, recordBuffer, color1, tlBanks, trBanks, blBanks, brBanks, banks, bankMap, recordingState, bankSet, bankToSaveTo, bankToRecording, recordColor, tempLoopTask, createRecordedTask, playingBanks, metronomeFlashTask, recordingInterim, resetRecordingState, interruptLooping, controlChanButton, arrowButtons, color2, up, down, left, right, padsByChannel, recordingStartBeat, quantize;

MIDIClient.init;
MIDIIn.connectAll;
launchpadOut = MIDIOut.newByName("Launchpad Pro", "Standalone Port");
launchpadOut.latency = 0;
midiOut = MIDIOut.newByName("IAC Driver", "Bus 1");
midiOut.latency = 0;

a = [1, 2, 3, 4];
b = [5, 6, 7, 8];

pads = Set.new();
padMap = Dictionary.new(); //launchpad-midiNote -> (padInd, channelInd)

makePadList = {|n1, n2, chan|
	var lis = List.new();
	k = 0;
	n1.do({|i| n2.do({|j|
		lis.add((i*10)+j);
		pads.add((i*10)+j);
		padMap.put((i*10)+j, [k, chan]);
		k = k+1;
	})});
	lis
};

recordBuffer = List.new(200);

padTL = makePadList.(b, a, 0);
padTR = makePadList.(b, b, 1);
padBL = makePadList.(a, a, 2);
padBR = makePadList.(a, b, 3);
padsByChannel = [padTL, padTR, padBL, padBR];

(pads - padMap.keys()).postln;

colorTL1 = 39;
colorTR1 = 112;
colorBL1 = 4;
colorBR1 = 83;
color1 = [colorTL1, colorTR1, colorBL1, colorBR1];

colorTL2 = 25;
colorTR2 = 45;
colorBL2 = 72;
colorBR2 = 13;
color2 = [colorTL2, colorTR2, colorBL2, colorBR2];

colorON = 13;

tlBanks = [50, 60, 70, 80];
trBanks = [59, 69, 79, 89];
blBanks = [10, 20, 30, 40];
brBanks = [19, 29, 39, 49];
banks = [tlBanks, trBanks, blBanks, brBanks];
bankSet = Set.new();
bankSet.addAll(banks.flatten(1));
bankMap = Dictionary.new(); //midiNote -> [bankInd, bankChan, isOn, loopTask/nil]
(0..3).do({|i| (0..3).do({|j|
	//launchpadOut.control(0, j, color1[i]);
	bankMap.put(banks[i][j], [j, i, false, nil]);
})});
bankSet.do({|i| launchpadOut.control(0, i, 0)});
playingBanks = Set.new();

//define scales and roots
scales = [
	[0, 2, 3, 5, 7, 10], //TL
	[0, 3, 5, 7, 10], //TR
	[0, 2, 3, 5, 7, 8, 10], //BL
	[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], //BR
];
roots = [66, 66, 42, 36];

indToNote_ = {|ind, scale, root, trans|
	root + scale[(ind+trans)%scale.size()] + (((ind+trans) / scale.size).floor * 12);
};

indToNote = {|ind, chan| indToNote_.(ind, scales[chan], roots[chan], transposes[chan])};

transposes = [-1, 4, -12, 0 ]; //+- 4 corresponds to up/down a row, +-1 corresponds to left/right a column
arrowButtons = [91, 92, 93, 94];
up = 91;
down = 92;
right = 93;
left = 94;

interruptLoopButtons = [1, 2, 3, 4];
interruptLooping = [false, false, false, false, false];
launchpadOut.control(0, 1, colorTL1);
launchpadOut.control(0, 2, colorTR1);
launchpadOut.control(0, 3, colorBL1);
launchpadOut.control(0, 4, colorBR1);

controlChanInd = 0;
controlChanButton = 8;
launchpadOut.control(0, controlChanButton, color1[controlChanInd]);


//define setPadLights method
setPadLights = {|padMIDIs, c1, c2, padInd|
	(0..15).do({|i|
		var col;
		if(((i+transposes[padInd]) % scales[padInd].size) == 0, {col = c2}, {col = c1});
		launchpadOut.noteOn(0, padMIDIs[i], col);
	});
};

setPadLights.(padTL, colorTL1, colorTL2, 0);
setPadLights.(padTR, colorTR1, colorTR2, 1);
setPadLights.(padBL, colorBL1, colorBL2, 2);
setPadLights.(padBR, colorBR1, colorBR2, 3);

launchPad = MIDIClient.sources.select({|elem| (elem.name == "Standalone Port")
	&& (elem.device == "Launchpad Pro")})[0];
[launchPad, MIDIClient.sources[2]].postln;
a = {|vel, note, chan, port|
	if(pads.includes(note), {
		var padInfo = padMap[note];
		var newNote = indToNote.(padInfo[0], padInfo[1]);
		midiOut.noteOn(padInfo[1], newNote, vel);
		if(recordingMetronome, {recordBuffer.add([tempoClock.beats, newNote, vel, padInfo[1], "on"])});
	});
};
padOn = MIDIFunc.noteOn(a, nil, nil, launchPad.uid);

b = {|vel, note, chan, port|
	if(pads.includes(note), {
		var padInfo = padMap[note];
		var newNote = indToNote.(padInfo[0], padInfo[1]);
		midiOut.noteOff(padInfo[1], newNote, vel);
		if(recordingMetronome, {recordBuffer.add([tempoClock.beats, newNote, vel, padInfo[1], "off"])});
	});
};
padOff = MIDIFunc.noteOff(b, nil, nil, launchPad.uid);
x = 0;
tempLoopTask = nil; //this var is only not nil when you have a recorded and unsaved loop

//TODO: alternative - quantaize to 4ths or 6ths, chose based on minimum error (can change per beat)
//{hit[0] = hit[0].floor + ((hit[0]%1 * 6).round / 6)}
quantize = {|recBuf, quantDivArray, startBeat|

	//divide array into hits-per-beat
	//apply calc-error-for-hits-and-div
	//select div with least error
	var currentBeat = 0;
	var listsPerBeat = List.new();
	var quantizedHits = List.new();
	listsPerBeat.add(List.new());
	recBuf.do({|hit| if(hit[0] < startBeat, {hit[0] = startBeat}) });

	recBuf.do({|hit|
		var indexBeat = hit[0].floor-startBeat;
		["HIT", indexBeat, currentBeat, hit].postln;
		if(indexBeat > currentBeat, {
			listsPerBeat.add(List.new());
			currentBeat = indexBeat;
		});
		listsPerBeat[currentBeat].add(hit);
	});
	"POST THAT".postln;

	listsPerBeat.do({|hits|
		var quantLists = List.new();
		var bestList = [List.new(), 1];
		var quantHitList;
		quantDivArray.do({|div|
			var quantList = List.new();
			var error = 0; //TODO: ignore noteOff messages for quantization?
			hits.do({|hit| quantList.add(hit[0].floor + ((hit[0]%1 * div).round / div))});
			(hits.size-1).do({|i| error = error + (hits[i][0] - quantList[i]).abs});
			quantLists.add([quantList, error]);
		});
		quantLists.do({|listErr| if(listErr[1] < bestList[1], {bestList = listErr})});
		quantHitList = List.fill(hits.size, {|i|
			var newHit = List.newFrom(hits[i]);
			newHit[0] = bestList[0][i];
			newHit
		});
		quantizedHits.add(quantHitList);
	});

	quantizedHits.inject([], _++_);
};


createRecordedTask = {|oldRecBuf|
	var startBeat, endBeat, timeAfterLastHit, recBuf, newTask, hangingNotes, chan, quantLevels, bestQuantLev;

	recBuf = List.newFrom(oldRecBuf);
	startBeat = recordingStartBeat;//recBuf[0][0].floor;
	quantLevels = [4, 6];

	/*recBuf.do({|hit|
		if(hit[0] < startBeat,
			{hit[0] = startBeat},
			//TODO: alternative - quantaize to 4ths or 6ths, chose based on minimum error (can change per beat)
			{hit[0] = hit[0].floor + ((hit[0]%1 * 6).round / 6)}
		);
	});*/
	["SIZE PRE QUANT", recBuf.size].postln;
	recBuf = quantize.(recBuf, quantLevels, startBeat);
	["SIZE POST QUANT", recBuf.size].postln;
	timeAfterLastHit = (recBuf[recBuf.size-1][0].ceil - recBuf[recBuf.size-1][0]);

	//TODO: handle cases where multiple inst hits in a recBuf, or when there's no noteOns recorded
	chan = recBuf[0][3];
	midiOut.allNotesOff(chan);
	hangingNotes = Dictionary.new();
	recBuf.do({|elem|
		if(elem[4] == "on",
			{hangingNotes.put(elem[1], elem)},
			{hangingNotes.removeAt(elem[1])})
	});
	endBeat = recBuf[recBuf.size-1][0].floor;
	hangingNotes.keys.do({|elem|
		var newHit = Array.newFrom(hangingNotes[elem]);
		newHit[0] = endBeat + 0.9999;
		recBuf.add(newHit);
	});

	recBuf.do({|hit| if(true/*hit[4] == "on"*/, {["HIT TIME", hit[4], hit[0]].postln})});

	(recBuf.size-1..1).do({|i| recBuf[i][0] = recBuf[i][0] - recBuf[i-1][0]});
	recBuf[0][0] = recBuf[0][0] - startBeat;

	//recBuf.do({|hit| ["Duration TIll", hit[4], hit[0]].postln});
	//["time after last", timeAfterLastHit].postln;

	newTask = Task({
		var ind = 0;
		var hit;
		var endWait = 0;
		{
			hit = recBuf[ind];
			hit[0].wait;
			if(interruptLooping[chan].not, {
				if(hit[4] == "on", {midiOut.noteOn(hit[3], hit[1], hit[2]);});
				if(hit[4] == "off", {midiOut.noteOff(hit[3], hit[1], hit[2])});
			});
			ind = ind+1;

			if(ind == recBuf.size, {timeAfterLastHit.wait});
			ind = ind%recBuf.size;
		}.loop;
	}, tempoClock);

	newTask;
};

//TODO: move variable instations to near the functions that use them
tempoClock = TempoClock.new(1);
t = tempoClock;
tapTempoSetButton = 5;
tapTempoToggle = 6;
recordButton = 7;
recordColor = 5;
launchpadOut.control(0, recordButton, recordColor);
lastTap = TempoClock.beats;
playMetronome = false;
recordingMetronome = false;
recordingInterim = false;
preRecordCount = 0;
preRecordLength = 4;
//0: not recording, 1: "record" hit, 2: bank specified, 3: pre record metronome, 4: actually recording notes
recordingState = 0;
bankToSaveTo = 0;
bankToRecording = Dictionary.new();
c = {|vel, note, chan, port|
	if(interruptLoopButtons.includes(note), {
		var chan = note - interruptLoopButtons[0];
		if((vel == 127), {midiOut.allNotesOff(chan)});
		interruptLooping[chan] = vel == 127;
	});
	if((note == tapTempoSetButton) && (vel == 127), {
		var now = TempoClock.beats;
		if((now - lastTap) < 2, {tempoClock.tempo = 1/(now-lastTap)});
		lastTap = now;
	});
	if((note == tapTempoToggle) && (vel == 127), {playMetronome = playMetronome.not});
	if((note == recordButton) && (vel == 127), {
		//TODO = case statement
		if(recordingState == 0, {
			bankToSaveTo = 0;
			recordingState = 1;
			recordingMetronome = true;
			preRecordCount = 0;
		});
		if(recordingState == 3, {
			tempLoopTask.stop;
			recordBuffer.do({|elem| midiOut.noteOff(elem[3], elem[1])});
			tempLoopTask.free;

			resetRecordingState.();
		});
		if(recordingState == 2, {
			recordingState = 3;
			preRecordCount = 0;
			recordingMetronome = false;
			tempLoopTask = createRecordedTask.(recordBuffer);
			tempoClock.sched(tempoClock.timeToNextBeat, {tempLoopTask.start; nil;});
		});
	});
	if(bankSet.includes(note) && (vel == 127), {
		if(recordingState == 3,
			{
				//save the recorded buffer to the appropriate bank
				bankMap[note][2] = true;
				bankMap[note][3] = tempLoopTask;
				playingBanks.add(note);

				resetRecordingState.();
			},
			{
				var thisBank = bankMap[note];
				if(thisBank[3] != nil, {
					tempoClock.sched(tempoClock.timeToNextBeat, {
						if(thisBank[2].not,
							{
								if(false, {//with this as false, banks can be overlayed
								//for all other banks for this inst, stop playing and turn their lights on
								banks[thisBank[1]].do({|bNote|
									if(bankMap[bNote][3] != nil, {
										var elem = bankMap[bNote];
										elem[3].stop;
										elem[2] = false; //TODO: refactor to make bank on/off functions
										Task({0.001.wait; launchpadOut.control(0, bNote, color1[elem[1]]);}).play;
										playingBanks.remove(bNote);
									})
								});});
								midiOut.allNotesOff(thisBank[1]);
								thisBank[3].start;
								thisBank[2] = true;
								playingBanks.add(note);
							},
							{
								midiOut.allNotesOff(thisBank[1]);
								"TURNING OFF".postln;
								thisBank[3].stop;
								thisBank[2] = false;
								launchpadOut.control(0, note, color1[thisBank[1]]);
								playingBanks.remove(note);
						});
						"TEMPOCLOCK FUNC RUN".postln;
						//launchpadOut.control(0, note, 0);
						nil;
					});
				});
		});
	});
	if((note == controlChanButton) && (vel == 127), {
		controlChanInd = (controlChanInd+1) % 4;
		launchpadOut.control(0, controlChanButton, color1[controlChanInd]);
	});
	if(arrowButtons.includes(note) && (vel == 127), {
		var ind = controlChanInd;
		if(note == up, {transposes[ind] = transposes[ind] - 4});
		if(note == down, {transposes[ind] = transposes[ind] + 4});
		if(note == right, {transposes[ind] = transposes[ind] + 1});
		if(note == left, {transposes[ind] = transposes[ind] - 1});
		setPadLights.(padsByChannel[ind], color1[ind], color2[ind], ind);
	});
};
MIDIFunc.cc(c, nil, nil, launchPad.uid);

resetRecordingState = {
	recordingMetronome = false;
	recordingState = 0;
	launchpadOut.control(0, recordButton, recordColor);
	recordBuffer.clear();
	tempLoopTask = nil;
};

metronomeFlashTask = Task({
	if(recordingMetronome || (tempLoopTask != nil),
		{launchpadOut.control(0, recordButton, (recordingState==2).if(17,recordColor))});
	playingBanks.do({|bNote| launchpadOut.control(0, bNote, color1[bankMap[bNote][1]])});
	(tempoClock.beatDur/2).wait;
	if(recordingMetronome || (tempLoopTask != nil), {launchpadOut.control(0, recordButton, 0)});
	playingBanks.do({|bNote| launchpadOut.control(0, bNote, 0)});
});

metronomeFunc = {
	metronomeFlashTask.start;
	if(recordingMetronome, {
		if((preRecordCount < preRecordLength),
			{
				recordingInterim = true;
				preRecordCount = preRecordCount + 1;
				["prerecordMetronome", preRecordCount].postln;
			},
			{//TODO: clean up and write comments for recroding state handling
				if(recordingState == 1, {
					recordingState = 2;
					recordingStartBeat = tempoClock.beats.round;
				});
				recordingInterim = false;
				"RECORDING".postln;
			}

		);
	});
	if(playMetronome, {
		if(recordingMetronome,
			{
				Task({ //TODO - refactor duration note on/off stuff into functions
					var drum = recordingInterim.if(37, 38);
					midiOut.noteOn(4, drum, 64); 0.05.wait; midiOut.noteOff(4, drum, 64);}).play;
			},
			{
				Task({midiOut.noteOn(4, 36, 64); 0.05.wait; midiOut.noteOff(4, 36, 64); }).play;
		});
	});
	//["beat", tempoClock.beats, tempoClock.beatDur].postln;
	1;
};
tempoClock.beats = 0;
tempoClock.schedAbs(1, metronomeFunc);

/*
basic layout
   - 4 keyboards, 1 in each quadrant, with 4 melody banks each (color coded on side - buttons)
     where the bank button of a playing bank will be flashing
   - keyboards will have "highlighted" scale roots, and you can "shift" the keyboard up/down/left right
     just like in the quneoSoloKeyboard by using the arrow keys
   - there will be a metronome for keeping the "pulse", and all recorded loops will be an integral
     number of pulses in duration
   - 3 main control buttons (top row) - tap tempo (flashes with metronome), metronome audio on/off,
     recording start/stop, (optionally) "visual play" on/off. "visual play" means that when a clip plays,
     the keyboard layout for that instrument will revert to what it was when the clip was recorded, and
     the "keys" will light up as the note sounds (might not be doable if keyboard is shifted while recording)
   - how to do "interrupt looping"? separate interupt-button for each instrument, held down to "interupt",
     or simply hold down flashing/playing clip to interupt it?
   - what if you want to replay a clip from the start when its already playing
   - saved clip will be launched at start of next complete "pulse", with minor "lateness" in pad hit forgiven
*/

)

// ================================================================================================
// ================================================================================================
//SCRATCH CODE




Task({}) != nil
(
MIDIClient.init;
var cfunc;
var midiOut = MIDIOut.newByName("IAC Driver", "Bus 1");
midiOut.latency = 0;
a = TempoClock.new(1);
b = TempoClock.new(1);

cfunk = {
	midiOut.(0, 60, 80);
	1;
	b.queue = a.queue
}
)
(
t = Task({ { "I'm loopy".postln; 1.wait;}.loop });
t.start;//TODO: see what results in "already playing" errors (use task.isPlaying)
)
t.play
(
a = 5;
a+=1
)

