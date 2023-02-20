export async function init(ctx, info) {
  await ctx.importCSS("./main.css");
  await ctx.importJS("https://unpkg.com/jmuxer");

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
      readFpsFromTrack: true,
      fps: info.framerate,
      debug: true,

      onError: function (data) {
        console.error(data);
        if (/Safari/.test(navigator.userAgent) && /Apple Computer/.test(navigator.vendor)) {
          jmuxer.reset();
        }
      },
    });
  });

  ctx.handleEvent("buffer", ([info, buffer]) => {
    let video = null;
    let audio = null;

    if (mode !== "both" && mode !== info.type) {
      throw new Error(`Invalid type: ${info.type} for a ${mode} player`);
    }

    if (info.type === "both") {
      video = new Uint8Array(buffer.slice(0, info.video_size));
      audio = new Uint8Array(buffer.slice(info.video_size));
    } else if (info.type === "video") {
      video = new Uint8Array(buffer);
    } else if (info.type === "audio") {
      audio = new Uint8Array(buffer);
    }

    if (info.stream === "raw") {
      const data = {
        video: video,
        audio: audio,
      };

      jmuxer.feed(data);
    } else if (info.stream === "mp4") {
      for (const [type, payload] of [["video", video], ["audio", audio]]) {
        if (payload === null) {
          continue;
        }
        const data = {
          type: type,
          payload: payload,
          dts: info.dts
        };

        console.log("Buffer", data);

        jmuxer = createBuffer(jmuxer);
        jmuxer.onBuffer(data);

      }
    }

    function createBuffer(jmuxer) {
      if (!jmuxer.mseReady || !jmuxer.remuxController || jmuxer.bufferControllers) return jmuxer;
      jmuxer.bufferControllers = {};
      for (let type in jmuxer.remuxController.tracks) {
        let track = jmuxer.remuxController.tracks[type];
        const codec = `${type}/mp4; codecs="${track.mp4track.codec}"`;
        if (!JMuxer.isSupported(codec)) {
          console.error('Browser does not support codec');
          return null;
        }
        let sb = jmuxer.mediaSource.addSourceBuffer(codec);
        jmuxer.bufferControllers[type] = new BufferController(sb, type);
        jmuxer.bufferControllers[type].on('error', jmuxer.onBufferError.bind(jmuxer));
      }
      return jmuxer;
    }

  });
}
