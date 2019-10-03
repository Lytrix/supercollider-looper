( // User Settings ################################################

var n = NetAddr.localAddr; //var n = NetAddr("localhost", 4559);
var encoders_per_channel = 5;
var encoder_names = ["Sample", "Volume", "Rate", "Start", "Length"];
var encoder_osc = ["switch", "amp", "rate", "start", "dur"];
var encoder_alt_names = ["Delay", "Pitch"];

// Set Up #######################################################

// Encoders
var encoderGUI = { { 0 }.dup(encoders_per_channel) }.dup(~channels);
var encoderSteps = 20;
var encoderValue = { { encoderSteps/2 }.dup(encoders_per_channel) }.dup(~channels);

// Buttons
var playBtn, altBtn, buttonCtl, pitchEncoder;
//var lockBtn = Array.fill(~channels, 0);
var muteBtn = Array.fill(~channels, 0);
var pitchValue = 1;

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
w.bounds_(Rect(w.bounds.left, w.bounds.top,(btnWidth+6)*(encoders_per_channel+2),(~channels + 1) * 120 + 30));
w.view.decorator = d = FlowLayout(w.view.bounds);
w.view.decorator.gap = 5@5;
//    },
//    { w.front; }
//);

// Action Functions #############################################

// Encoder OSC Message
e = { |value, channel, i|
	var msg;
    if (~altStatus == 0 ||(i > (encoder_alt_names.size - 1))) {
        msg = "/" ++ encoder_osc[i];
	} {
       msg = "/" ++ encoder_alt_names[i].toLower;
	};
	// /switch works as a Rotary Encoder
	if (i == 0) {
		encoderValue[channel][i] = value - encoderValue[channel][i];
		if (encoderValue[channel][i] == encoderSteps, { encoderValue[channel][i] = 1.neg });
		if (encoderValue[channel][i] == (encoderSteps.neg), { encoderValue[channel][i] = 1 });
		n.sendMsg( msg, channel, encoderValue[channel][i] );
		msg.scatArgs(channel, encoderValue[channel][i]).postln;
		encoderValue[channel][i] = value;
	// Works as a knob
	} {
		n.sendMsg( msg, channel, value );
		msg.scatArgs(channel, value).postln;
	}
};

// Random
r = { |t, i|
    var isRandom = false;
    if (~altStatus == 0) {
        if( i != 1 ) { // All but Volume
            isRandom = true;
        }
    } {
        if (i <= (encoder_alt_names.size -1)) { // Only alt encoders
            isRandom = true;
        }
    };
    if (isRandom == true) { encoderGUI[t][i].value_(rrand(0, encoderSteps)).doAction; }
};

// GUI Elements ###############################################

~channels.do { |t|

	// Encoder ////////////////////////////////////////////////
	encoders_per_channel.do{ |i|
		encoderGUI[t][i] = EZKnob(
			w,
			knobbounds,
			encoder_names[i],
            ControlSpec(0, encoderSteps, step:1, default:encoderSteps / 2),
			{ |ez| e.value(ez.value, t, i); }, // Action
			initAction: false
		);
	};

	d.shift(x: 0, y: 40); // Sets the indentation for lockBtn

	// Mute //////////////////////////////////////////////////
	muteBtn[t] = Button(w, btntrackbounds)
	.states_( [
		["Mute", Color.white, Color.blue(0.27)],
		["Muted", Color.white, Color.red(0.7)],
	])
	.mouseDownAction_({ arg view;
		var msg;
		msg = "/mute";
        n.sendMsg( "/mute", t, view.value );
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
            r.value(t, i);
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
			encoders_per_channel.do{ |i|
                r.value(t, i);
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
            encoder_alt_names.size.do{ |encoder|
                ~channels.do{ |i|
                    encoderGUI[i][encoder].set(encoder_alt_names[encoder]);
                    encoderGUI[i][encoder].setColors(stringColor:Color.red()).font_(Font(bold:true));
                }
            };
		} {
			~altStatus = 0;
            encoder_alt_names.size.do{ |encoder|
				~channels.do{ |i|
                     encoderGUI[i][encoder].set(encoder_names[encoder]);
				     encoderGUI[i][encoder].setColors(stringColor:Color.black()).font_(Font(bold:false));
                }
			}
		}
	})
	.valueAction_(0);

// Pitch OSC Message
p = { |channel, value|
	var msg;
	msg = "/pitch";
    // Old Version: Sends Steps instead of Value
	//pitchValue = value - pitchValue;
	//if (pitchValue == encoderSteps, { pitchValue = 1.neg });
	//if (pitchValue == (encoderSteps.neg), { pitchValue = 1 });
    //n.sendMsg( msg, channel, encoderValue[t][i] );
	n.sendMsg(msg, channel, value);
	msg.scatArgs(channel, value).postln;
	//pitchValue = value;
};

pitchEncoder = EZKnob(
	w,
	knobbounds,
	"Pitch",
	ControlSpec(0, encoderSteps, step:1, default:encoderSteps/2),
    { |ez| p.value(-1, ez.value) }, // Action
	initAction: false
);

pitchEncoder.setColors(Color.blue(0.27),Color.white,Color.blue(0.27), Color.white, Color.white,nil,nil, Color.grey(0.7));

// Text ///////////////////////////////////////////////////

staticText = StaticText(w,  Rect(0, 0, 250, 120))
	.background_(Color.white())
	.string_("Samplemàtic I2CEncoders")
	.font_(Font("Helvetica", 30, true))
	.align_(\center);

// Init ///////////////////////////////////////////////////
~channels.do{ |t|
	encoders_per_channel.do{ |i|
		r.value(t, i);
	}
}

)
