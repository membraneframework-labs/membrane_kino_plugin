export function init(ctx, info) {
  ctx.importCSS("./main.css");
  ctx.importJS("https://unpkg.com/jmuxer");

  console.log("Init", info);

  let jmuxer = "kek";
  const mode = info.type;

  if (!["video", "audio", "both"].includes(mode)) {
    throw new Error(`Invalid mode: ${mode}`);
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
    jmuxer = new JMuxer({
      node: `player-${id}`,
      mode: mode,
      flushingTime: 0,
      clearBuffer: false,
      readFpsFromTrack: false,
      fps: info.framerate,
      debug: false,

      onError: function (_data) {
        if (/Safari/.test(navigator.userAgent) && /Apple Computer/.test(navigator.vendor)) {
          jmuxer.reset();
        }
      }
    });

    if (jmuxer !== null) {
      jmuxer.clearBuffer();
    } else {
      // jmuxer = new JMuxer({
      //   node: `player-${id}`,
      //   mode: mode,
      //   flushingTime: 0,
      //   clearBuffer: false,
      //   readFpsFromTrack: false,
      //   fps: info.framerate,
      //   debug: false,

      //   onError: function (_data) {
      //     if (/Safari/.test(navigator.userAgent) && /Apple Computer/.test(navigator.vendor)) {
      //       jmuxer.reset();
      //     }
      //   }
      // });
    }

  });

  ctx.handleEvent("buffer", ([info, buffer]) => {
    let video = null;
    let audio = null;

    if (mode === "video") {
      video = new Uint8Array(buffer);
    } else if (mode === "audio") {
      audio = new Uint8Array(buffer);
    } else {
      if (info.type === "both") {
        video = new Uint8Array(buffer.slice(0, info.video_size));
        audio = new Uint8Array(buffer.slice(info.video_size));
      } else {
        if (info.type === "video") {
          video = new Uint8Array(buffer);
        } else if (info.type === "audio") {
          audio = new Uint8Array(buffer);
        } else {
          throw new Error(`Invalid type: ${info.type}`);
        }
      }
    }

    const duration = "duration" in info ? info.duration : null;

    jmuxer.feed({
      video: video,
      audio: audio,
      duration: duration,
    });
  });
}
