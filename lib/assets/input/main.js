function send_error(err) {
  ctx.pushEvent("error", err);
  console.error(err);
}

function sending_error(fn) {
  return async (...args) => {
    try {
      return await fn(...args);
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
  
  let recorder_audio = null;
  let recorder_video = null;
  let state = "ready"

  let microphone_icon = "";
  let camera_icon = "";
  
  if (audio_enabled) {
    microphone_icon = '<i class="ri-mic-line text-lg leading-none mr-2" aria-hidden="true"></i>'
  }
  if (video_enabled) {
    camera_icon = '<i class="ri-camera-line text-lg leading-none mr-2" aria-hidden="true"></i>'
  }

  ctx.root.innerHTML = `
    <div id="clients" class="clients">
      <div class="client">
      <button id="record-button" class="button-base button-gray border-transparent py-2 px-4 inline-flex text-gray-500" data-btn-record="">
      `
        + camera_icon
        + microphone_icon 
        + `
        <span>Record</span>
      </button>
      </div>
      <div class="client">
        <span id="reload-info-text"></span>
      </div>
    </div>
    `;
  const record_button = ctx.root.querySelector("#record-button");
  const reload_info_text = ctx.root.querySelector("#reload-info-text");

  ctx.handleEvent("create", (info) => {
    console.log("create", info);
  });

  const streamAudioTracks = sending_error(async () => {
    let stream;
    stream = await navigator.mediaDevices.getUserMedia({ video: false, audio: true });
    const audio_track = stream.getAudioTracks()[0];
    const audio_stream_constraints = {
      channelCount: { exact: 1 },
      sampleRate: { exact: 48000 },
      sampleSize: { exact: 16 },
    };
    await audio_track.applyConstraints(audio_stream_constraints);
    
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
  });

  const streamVideoTracks = sending_error(async () => {
    let stream;
    stream = await navigator.mediaDevices.getUserMedia({ video: true, audio: false });
    const video_track = stream.getVideoTracks()[0];
    const video_stream_constraints = {
      width: { ideal: info.type.video.desired_width },
      height: { ideal: info.type.video.desired_height },
      frameRate: { ideal: info.type.video.desired_framerate },
      resizeMode: { exact: "crop-and-scale" },
      advanced: [{ width: 1920, height: 1080, framerate: 30 }, { width: 1920, height: 1080 }],
    };

    await video_track.applyConstraints(video_stream_constraints);
    
    let video_settings = video_track.getSettings();
    ctx.pushEvent('framerate', video_settings.frameRate);

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
  });

  const startRecording = sending_error(async () => {
    let success = false;
    if (audio_enabled && video_enabled) {
      recorder_audio = await streamAudioTracks();
      recorder_video = await streamVideoTracks();
      if (recorder_audio != null && recorder_video != null) {
        success = true
      }
    }
    else if (audio_enabled) {
      recorder_audio = await streamAudioTracks();
      if (recorder_audio != null) {
        success = true
      }
    }
    else if (video_enabled) {
      recorder_video = await streamVideoTracks();
      if (recorder_video != null) {
        success = true
      }
    }
    if (success) {
      record_button.querySelector('span').innerText = 'Stop';
      state = "recording";
      ctx.pushEvent('recording_started', {});
    }
  });

  const stopRecording = sending_error(async () => {
    record_button.querySelector('span').innerText = 'Record';

    if(recorder_audio != null) {
      try {
        recorder_audio.stop();
      } catch (error) {
        ctx.pushEvent("error", `Error while stopping audio stream: ${error.message}`);
      }
      recorder_audio.stream.getAudioTracks().forEach(track => track.stop());
    }
    if(recorder_video != null) {
      try {
        recorder_video.stop();
      } catch (error) {
        ctx.pushEvent("error", `Error while stopping video stream: ${error.message}`);
      }
      recorder_video.stream.getVideoTracks().forEach(track => track.stop());
    }
    state = "stopped";
    ctx.pushEvent('recording_stopped', {});
  });

  record_button.addEventListener('click', async () => {
    if (state == "ready") {
      await startRecording();
    } else if (state == "recording") {
      await stopRecording();
    } else if (state == "stopped") {
      reload_info_text.innerText = 'Reevaluate cell to restart recording';
    }
  });

}

