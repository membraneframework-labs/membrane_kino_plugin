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
  const mode = info.type;

  if (!["video", "audio", "both"].includes(mode)) {
    send_error(`Invalid mode: ${mode}`);
  }

  let id = info.client_id;

  const html_player_type = mode === "both" ? "video" : mode;

  ctx.root.innerHTML = `
    <div class="client">
      <div class="frame-container">
        <${html_player_type} controls autoplay playsinline" id="player-${id}">
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
        mode: mode,
        flushingTime: 0,
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

      ctx.pushEvent("jmuxer_ready", id);

    } catch (e) {
      send_error(e.message);
    }
  });

  ctx.handleEvent("buffer", async ([info, buffer]) => {
    try {
      let video = null;
      let audio = null;

      if (mode === "both" && info.type === "both") {
        video = new Uint8Array(buffer.slice(0, info.video_size));
        audio = new Uint8Array(buffer.slice(info.video_size));
      } else {
        const type = mode !== "both" ? mode : info.type;
        switch (type) {
          case "video":
            video = new Uint8Array(buffer);
            break;
          case "audio":
            audio = new Uint8Array(buffer);
            break;
          default:
            throw new Error(`Invalid type: ${info.type} for a ${mode} player`);
        }
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
}
