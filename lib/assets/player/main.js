export async function init(ctx, info) {
  await ctx.importCSS("./main.css");
  await ctx.importJS("./deps/jmuxer.js");
  // await ctx.importJS("https://unpkg.com/jmuxer");

  console.log("Init", info);

  let jmuxer = null;
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

      onError: function (_data) {
        if (/Safari/.test(navigator.userAgent) && /Apple Computer/.test(navigator.vendor)) {
          jmuxer.reset();
        }
      }
    });
  });

  ctx.handleEvent("buffer", ([info, buffer]) => {
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
  });
}
