function send_error(err) {
  ctx.pushEvent("error", err);
  console.error(err);
}

function sending_error(fn) {
  return async (...args) => {
    try {
      return fn(...args);
    } catch (err) {
      send_error(err.message);
    }
  }
}

const import_resources = sending_error(async (ctx) => {
  const css = ctx.importCSS("./main.css");
  const icons = ctx.importCSS("https://cdn.jsdelivr.net/npm/remixicon@3.2.0/fonts/remixicon.min.css");
  return Promise.all([css, icons]);
});


export async function init(ctx, info) {
  await import_resources(ctx);

  const duration_ms = info.flush_time;

  const audio_enabled = info.type.audio;
  const video_enabled = info.type.video;

  let recorder = null;
  let recording = false;

  let microphone_html = "";
  let camera_html = "";
  
  if (audio_enabled) {
    microphone_html = '<i class="ri-mic-line text-lg leading-none mr-2" aria-hidden="true"></i>'
  }
  if (video_enabled) {
    camera_html = '<i class="ri-camera-line text-lg leading-none mr-2" aria-hidden="true"></i>'
  }

  ctx.root.innerHTML = `
    <div id="clients" class="clients">
      <div class="client">
      <button id="record-button" class="button-base button-gray border-transparent py-2 px-4 inline-flex text-gray-500" data-btn-record="">
      `
        + camera_html
        + microphone_html 
        + `
        <span>Record</span>
      </button>
      </div>
    </div>
    `;
  const record_button = ctx.root.querySelector("#record-button");

  ctx.handleEvent("create", (info) => {
    console.log("create", info);
  });

  const streamMediaTracks = sending_error(async () => {
    let stream;
    const constraints = { video: video_enabled, audio: audio_enabled };
    try {
      stream = await navigator.mediaDevices.getUserMedia(constraints);
      // only audio config
      if (audio_enabled && !video_enabled) {
        const audio_track = stream.getAudioTracks()[0];
        const audio_stream_constraints = {
          channelCount: { exact: 1 },
          sampleRate: { exact: 48000 },
          sampleSize: { exact: 16 },
        };
        audio_track.applyConstraints(audio_stream_constraints);
        console.log("audio settings", audio_track.getSettings());
        
        const options = {
          mimeType: 'audio/webm;codecs=opus'
        };
        const recorder = new MediaRecorder(stream, options);

        recorder.addEventListener('dataavailable', async ({ data }) => {
          const result = await data.stream().getReader().read();
          ctx.pushEvent('audio_frame', [{ duration: duration_ms }, result.value.buffer]);
        });

        recorder.start(duration_ms);
        return recorder;
      }
      // only video config 
      else if (video_enabled && !audio_enabled) {
        const video_track = stream.getVideoTracks()[0];
        const video_stream_constraints = {
          frameRate: { exact: 30 },
          width: { exact: 640},
          height: { exact: 480 }
        };
        // applyConstraints doesn't do anything, both in audio and video, idk why
        video_track.applyConstraints(video_stream_constraints);
        console.log("video settings", video_track.getSettings());

        const options = {
          mimeType: 'video/webm;codecs=H264'
        };
        const recorder = new MediaRecorder(stream, options);

        recorder.addEventListener('dataavailable', async ({ data }) => {
          const result = await data.stream().getReader().read();
          ctx.pushEvent('video_frame', [{ duration: duration_ms }, result.value.buffer]);
        });

        recorder.start(duration_ms);
        return recorder;
      }
      // audio and video config
      else if (audio_enabled && video_enabled) {
        throw new Error("audio & video mode work in progress");
      }
    } catch (error) {
      throw new Error(`
        MediaDevices.getUserMedia() threw an error. 
        Stream did not open.
        ${error.name} - 
        ${error.message}
      `);
    }
  });

  const startRecording = sending_error(async () => {
    record_button.classList.add('recording');
    record_button.querySelector('span').innerText = 'Stop';

    recorder = await streamMediaTracks();
    recording = true;
    ctx.pushEvent('recording_started', {});
  });

  const stopRecording = sending_error(async () => {
    record_button.classList.remove('recording');
    record_button.querySelector('span').innerText = 'Record';

    recorder.stop();
    recording = false;
    ctx.pushEvent('recording_stopped', {});
  });

  record_button.addEventListener('click', async () => {
    if (recording) {
      await stopRecording();
    } else {
      await startRecording();
    }
  });

}
