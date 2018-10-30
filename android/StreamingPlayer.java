package me.tearadio.station;

/**
 * Created by hoangdoan on 5/10/17.
 */
import android.media.AudioManager;
import android.media.MediaPlayer;
import android.os.CountDownTimer;
import android.support.annotation.Nullable;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.modules.core.DeviceEventManagerModule;

public class StreamingPlayer extends ReactContextBaseJavaModule{

    private MediaPlayer mediaPlayer;
    private ReactApplicationContext context;
    CountDownTimer cTimer = null;
    String channelUrl;
    Boolean isError = false;

    public StreamingPlayer(ReactApplicationContext reactContext) {
        super(reactContext);
        this.context = reactContext;
    }

    @ReactMethod
    public void play(String url){
        channelUrl = url;
        try {
            if (mediaPlayer != null) {
                this.pause();
                mediaPlayer = null;
            }
            mediaPlayer = new MediaPlayer();
            mediaPlayer.setAudioStreamType(AudioManager.STREAM_MUSIC);
            mediaPlayer.setDataSource(url);
            mediaPlayer.prepareAsync();

            mediaPlayer.setOnErrorListener(new MediaPlayer.OnErrorListener() {
                @Override
                public boolean onError(MediaPlayer mp, int what, int extra) {
                    isError = true;
                    StreamingPlayer.this.pause();
                    WritableMap params = Arguments.createMap();
                    params.putString("name", "error");
                    sendEvent(StreamingPlayer.this.context, "StreamingPlayer", params);
                    return true;
                }
            });
            mediaPlayer.setOnPreparedListener(new MediaPlayer.OnPreparedListener() {
                @Override
                public void onPrepared(MediaPlayer mp) {
                    mediaPlayer.start();
                    WritableMap params = Arguments.createMap();
                    params.putString("name", "play");
                    sendEvent(StreamingPlayer.this.context, "StreamingPlayer", params);
                }
            });
            mediaPlayer.setOnInfoListener(new MediaPlayer.OnInfoListener() {
                @Override
                public boolean onInfo(MediaPlayer mp, int what, int extra) {
                    if (what == 701) {
                        isError = true;
                        StreamingPlayer.this.pause();
                    }
                    return true;
                }
            });

        } catch (Exception e) {
            WritableMap params = Arguments.createMap();
            params.putString("name", "error");
            sendEvent(this.context, "StreamingPlayer", params);
        }


    }

    @ReactMethod
    public void setPlayingInfoCenter(String title, String artist, String artwork) {

    }

    @ReactMethod
    public void pause() {
        try {
            if (mediaPlayer.isPlaying()) {
                mediaPlayer.pause();
                WritableMap params = Arguments.createMap();
                params.putString("name", "pause");
                sendEvent(this.context, "StreamingPlayer", params);
            }
        } catch (Exception e){
            WritableMap params = Arguments.createMap();
            params.putString("name", "error");
            sendEvent(this.context, "StreamingPlayer", params);
        }

    }

    @ReactMethod
    public void resume() {
        try {
            if(mediaPlayer.isPlaying()) {
                mediaPlayer.pause();
                WritableMap params = Arguments.createMap();
                params.putString("name", "pause");
                sendEvent(this.context, "StreamingPlayer", params);
            } else {
                if (isError) {
                    this.play(channelUrl);
                    isError = false;
                } else {
                    mediaPlayer.start();
                    WritableMap params = Arguments.createMap();
                    params.putString("name", "play");
                    sendEvent(this.context, "StreamingPlayer", params);
                }

            }
        } catch (Exception e){
            WritableMap params = Arguments.createMap();
            params.putString("name", "error");
            sendEvent(this.context, "StreamingPlayer", params);
        }

    }

    public void sendEvent(ReactContext reactContext, String eventName, @Nullable WritableMap params) {
        this.context.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                .emit(eventName, params);
    }

    @ReactMethod
    public void runTimer(int time){
        if (cTimer != null) {
            cTimer.cancel();
            cTimer = null;
            cTimer = new CountDownTimer(time * 60000, 1000) {
                @Override
                public void onTick(long millisUntilFinished) {
                    System.out.println(millisUntilFinished);
                    int totalSeconds = (int) millisUntilFinished/1000;
                    int hours = totalSeconds / 3600;
                    int minutes = totalSeconds / 60 % 60;
                    int seconds = totalSeconds % 60;

                    String timeString = String.format("%02d", hours) + ":" + String.format("%02d", minutes) + ":" + String.format("%02d", seconds);
                    WritableMap params = Arguments.createMap();
                    params.putString("name", "timer");
                    params.putString("seconds", timeString);
                    StreamingPlayer.this.sendEvent(StreamingPlayer.this.context, "StreamingPlayer", params);
                }

                @Override
                public void onFinish() {

                    StreamingPlayer.this.pause();
                    StreamingPlayer.this.resetTimer();
                }

            };
            cTimer.start();
        } else {
            cTimer = new CountDownTimer(time * 60000, 1000) {
                @Override
                public void onTick(long millisUntilFinished) {
                    System.out.println(millisUntilFinished);
                    int totalSeconds = (int) millisUntilFinished/1000;
                    int hours = totalSeconds / 3600;
                    int minutes = totalSeconds / 60 % 60;
                    int seconds = totalSeconds % 60;

                    String timeString = String.format("%02d", hours) + ":" + String.format("%02d", minutes) + ":" + String.format("%02d", seconds);
                    WritableMap params = Arguments.createMap();
                    params.putString("name", "timer");
                    params.putString("seconds", timeString);
                    StreamingPlayer.this.sendEvent(StreamingPlayer.this.context, "StreamingPlayer", params);
                }

                @Override
                public void onFinish() {

                    StreamingPlayer.this.pause();
                    StreamingPlayer.this.resetTimer();
                }

            };
            cTimer.start();
        }


    }

    @ReactMethod
    public void resetTimer() {
        if (cTimer != null) {
            cTimer.cancel();
            cTimer = null;
        }
        System.out.println("HELLO");
        WritableMap params = Arguments.createMap();
        params.putString("name", "timerNoti");
        sendEvent(this.context, "StreamingPlayer", params);
    }

    @Override
    public String getName() {
        return "StreamingPlayer";
    }

 }
