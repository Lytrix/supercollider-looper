( // User Settings ################################################

var n = NetAddr.localAddr; //var n = NetAddr("localhost", 4559);
var encoders_per_channel = 5;
var encoder_names = ["Sample", "Volume", "Rate", "Start", "Length"];
var encoder_osc = ["switch", "amp", "rate", "start", "length"];

// Set Up #######################################################

// Encoders
var encoderGUI = { { 0 }.dup(encoders_per_channel) }.dup(~channels);
var encoderSteps = 24;
var encoderValue = { { encoderSteps/2 }.dup(encoders_per_channel) }.dup(~channels);

// Buttons
var playBtn, altBtn, buttonCtl, pitchEncoder;
var lockBtn = Array.fill(~channels, 0);
var muteBtn = Array.fill(~channels, 0);
var detuneValue = 0;

// GUI Attributes
var btnWidth = 80;
var knobbounds = btnWidth@120;
var btntrackbounds = btnWidth@40;
var btnbounds = btnWidth@120;
var staticText;

~altStatus = 0;

// Window #######################################################


//if (w.isClosed == true,
//    {
w = Window.new("Samplematic").front;
w.alwaysOnTop = true;
w.bounds_(Rect(w.bounds.left, w.bounds.top,(btnWidth+6)*(encoders_per_channel+3),(~channels + 1) * 120 + 30));
w.view.decorator = d = FlowLayout(w.view.bounds);
w.view.decorator.gap = 5@5;
//    },
//    { w.front; }
//);

// Action Functions #############################################

// Encoder OSC Message
e = { |value, t, i|
	var msg;
	if (~altStatus == 0) {
        msg = "/" ++ encoder_osc[i];
	} {
		msg = "/attack";
	};
	encoderValue[t][i] = value-encoderValue[t][i];
	if (encoderValue[t][i] == encoderSteps, { encoderValue[t][i] = 1.neg });
	if (encoderValue[t][i] == (encoderSteps.neg), { encoderValue[t][i] = 1 });
    n.sendMsg( msg, t, encoderValue[t][i] );
	msg.scatArgs(t, encoderValue[t][i]).postln;
	encoderValue[t][i] = value;
};


// GUI Elements ###############################################

~channels.do { |t|

	// Encoder ////////////////////////////////////////////////
	encoders_per_channel.do{ |i|
		encoderGUI[t][i] = EZKnob(
			w,
			knobbounds,
			encoder_names[i],
			ControlSpec(0, encoderSteps, step:1, default:encoderSteps/2),
			{ |ez| e.value(ez.value, t, i); }, // Action
			initAction: true
		);
	};

	d.shift(x: 0, y: 40); // Sets the indentation for lockBtn

	// Lock //////////////////////////////////////////////////
	lockBtn[t] = Button(w, btntrackbounds)
	.states_( [
		["Lock", Color.white, Color.blue(0.27)],
		["Locked", Color.white, Color.red(0.7)],
	])
	.valueAction_(0);

	// Mute //////////////////////////////////////////////////
	muteBtn[t] = Button(w, btntrackbounds)
	.states_( [
		["Mute", Color.white, Color.blue(0.27)],
		["Muted", Color.white, Color.red(0.7)],
	])
	.mouseDownAction_({ arg view;
		var msg;
		msg="/mute";
		n.sendMsg(msg, t, view.value);
		msg.scatArgs(t, view.value).postln;
	})
	.valueAction_(0);

	// Random //////////////////////////////////////////////
	buttonCtl = Button(w, btntrackbounds)
	.states_( [
		["Random", Color.white, Color.blue(0.27)]
	])
	.mouseDownAction_({
		encoders_per_channel.do{ |i|
			if (lockBtn[t].value == 0) {
				encoderGUI[t][i].value_(rrand(0, encoderSteps)).doAction;
			}
		}
	})
	.valueAction_(0);

	d.shift(x: 0, y: 0);
	d.top_(d.top-40);

	w.view.decorator.nextLine;
};

// Play Button //////////////////////////////////////////////

playBtn = Button(w, btnbounds)
	.states_( [
		["Play", Color.white, Color.blue(0.27)],
		["Stop", Color.white, Color.red(0.7)],
	])
	.mouseDownAction_({ arg view;
		var msg;
		if (view.value == 0) {
		~channels.do{ |t|
				//muteBtn[t].value.postln;
				if (muteBtn[t].value==1) {
					msg="/mute/"++(t+1);
					n.sendMsg(msg, 0);
					msg.scatArgs(0).postln;
				}
		};
			msg="/play";
		} {
			msg="/stop";
		};
		n.sendMsg(msg, view.value);
		msg.scatArgs(view.value).postln;

	})
	.valueAction_(0);

// Random All Button ///////////////////////////////////////
playBtn = Button(w, btnbounds)
	.states_( [
		["Random\nAll", Color.white, Color.blue(0.27)]
	])
	.mouseDownAction_({
		~channels.do{ |t|
			if (lockBtn[t].value == 0) {
				//encoderGUI[t].value_(rrand(0, encoderSteps)).doAction;
				encoders_per_channel.do{ |i|
					encoderGUI[t][i].value_(rrand(0, encoderSteps)).doAction;
				}
			}
		}
	})
	.valueAction_(0);

// Alt Button //////////////////////////////////////////////

altBtn = Button(w, btnbounds)
	.states_( [
		["Alt", Color.white, Color.blue(0.27)],
		["Alt", Color.white, Color.red(0.7)],
	])
	.mouseDownAction_({ arg view;
		if (view.value == 0) {
			~altStatus = 1;
			~channels.do{ |i|
				encoderGUI[i][0].set("Attack");
				encoderGUI[i][0].setColors(stringColor:Color.red()).font_(Font(bold:true));
			}
		} {
			~altStatus = 0;
			~channels.do{ |i|
				encoderGUI[i][0].set(encoder_names[0]);
				encoderGUI[i][0].setColors(stringColor:Color.black()).font_(Font(bold:false));
			}
		}
	})
	.valueAction_(0);

// Encoder OSC Message
p = { |value|
	var msg;
	msg="/detune/";
	detuneValue=value-detuneValue;
	if (detuneValue == encoderSteps, { detuneValue=1.neg });
	if (detuneValue == (encoderSteps.neg), { detuneValue=1 });
	n.sendMsg(msg, detuneValue);
	msg.scatArgs(detuneValue).postln;
	detuneValue=value;
};

pitchEncoder = EZKnob(
	w,
	knobbounds,
	"Pitch",
	ControlSpec(0, encoderSteps, step:1, default:encoderSteps/2),
	{ |ez| p.value(ez.value); }, // Action
	initAction: true
);

pitchEncoder.setColors(Color.blue(0.27),Color.white,Color.blue(0.27), Color.white, Color.white,nil,nil, Color.grey(0.7));

// Text ///////////////////////////////////////////////////

staticText = StaticText(w,  Rect(0, 0, 330, 120))
	.background_(Color.white())
	.string_("Samplemàtic I2CEncoders")
	.font_(Font("Helvetica", 30, true))
	.align_(\center);
)