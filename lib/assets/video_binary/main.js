export function init(ctx, info) {
  ctx.importCSS("./main.css");
  ctx.importJS("https://unpkg.com/jmuxer");

  console.log("Init", info);

  let jmuxer = null;
  const mode = info.type;

  if (!["video", "audio", "both"].includes(mode)) {
    throw new Error(`Invalid mode: ${mode}`);
  }

  let id = info.client_id;

  ctx.root.innerHTML = `
    <div class="client">
      <div class="frame-container">
        <video controls autoplay playsinline muted" id="video-player-${id}">
        </video>
      </div>
    </div>
  `;

  ctx.handleEvent("create", (info) => {
    if (jmuxer !== null) {
      jmuxer.clearBuffer();
    } else {
      jmuxer = new JMuxer({
        node: `video-player-${id}`,
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
      video = new Uint8Array(buffer.slice(0, info.video_size));
      audio = new Uint8Array(buffer.slice(info.video_size));
    }

    jmuxer.feed({
      video: video,
      audio: audio,
    });
  });
}
