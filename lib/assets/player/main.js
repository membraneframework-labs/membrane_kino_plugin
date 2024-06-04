export async function init(ctx, info) {
  function send_error(err) {
    ctx.pushEvent("error", err);
    console.error(err);
  }

  try {
    await ctx.importCSS("./main.css");
    await ctx.importJS("https://unpkg.com/jmuxer/dist/jmuxer.js");
  } catch (err) {
    send_error(err.message);
  }

  let jmuxer = null;

  const bool_mapper = function (bool) {
    if (bool === "true") {
      return true;
    } else if (bool === "false") {
      return false;
    } else {
      throw new Error("Invalid value");
    }
  }
  const player_type = Object.fromEntries(Object.entries(info.type).map(([k, v]) => [k, bool_mapper(v)]));
  const mirror_video = info.mirror ? `class="video-mirror"` : ""
  const mirror_controlls = info.mirror ? `
    <style>
      video::-webkit-media-controls-panel {
        transform: scale(-1,1);
      }
    </style>
  ` : ""

  let jmuxer_mode = null;
  if (player_type.video && player_type.audio) {
    jmuxer_mode = "both";
  } else if (player_type.video) {
    jmuxer_mode = "video";
  } else if (player_type.audio) {
    jmuxer_mode = "audio";
  } else {
    send_error(`At least one of ${info.type} must be true`);
  }

  const flush_time = info.flush_time;
  const id = info.client_id;

  const html_player_type = jmuxer_mode === "both" ? "video" : jmuxer_mode;
  ctx.root.innerHTML = `
    <div class="client">
      <div class="frame-container">
        ${mirror_controlls}
        <${html_player_type} ${mirror_video} controls autoplay playsinline" id="player-${id}">
        </${html_player_type}>
      </div>
    </div>
  `;

  ctx.handleEvent("create", (info) => {
    try {
      if (jmuxer !== null) {
        return;
      }

      jmuxer = new JMuxer({
        node: `player-${id}`,
        mode: jmuxer_mode,
        flushingTime: flush_time,
        clearBuffer: false,
        readFpsFromTrack: false,
        fps: info.framerate,
        debug: false,

        onError: function (data) {
          if (/Safari/.test(navigator.userAgent) && /Apple Computer/.test(navigator.vendor)) {
            jmuxer.reset();
          }
          throw new Error(data);
        }
      });

      ctx.pushEvent("jmuxer_ready", info);

    } catch (e) {
      send_error(e.message);
    }
  });

  ctx.handleEvent("buffer", async ([info, buffer]) => {
    try {
      let video = new Uint8Array(buffer.slice(0, info.video_size));
      let audio = new Uint8Array(buffer.slice(info.video_size));

      if (video.length === 0 || !player_type.video) {
        video = null;
      }
      if (audio.length === 0 || !player_type.audio) {
        audio = null;
      }

      const duration = "duration" in info ? info.duration : null;

      jmuxer.feed({
        video: video,
        audio: audio,
        duration: duration,
      });

    } catch (e) {
      send_error(e.message);
    }
  });

  ctx.pushEvent("initialized", {});
}
