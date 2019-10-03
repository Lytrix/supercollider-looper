# SuperCollider Sample Looper with i2CEncoders

A version of Roger Pibernat's <a href="https://github.com/loopier/samplematic">Samplemàtic</a> to run with DUPPA's <a href="https://www.tindie.com/products/saimon/i2cencoder-v2-connect-multiple-encoder-on-i2c-bus/">i2CEncoders</a>.

The default looper has 5 encoders per channel, with alternative functions:

1. Encoder 1: Sample file index
2. Encoder 2: Volume
3. Encoder 3: Sample starting point
4. Encoder 4: Sample Length
5. Alt Encoder 5: Attack
6. Alt Encoder 5: Pitch

Each channel also has functions triggered by 2 buttons:

1. Send random values
2. Mute channel

The global functions control all channels:

1. Play / Stop switch
2. Send random to all channels
3. Alt switch
4. Pitch