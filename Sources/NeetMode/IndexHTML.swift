import Foundation

/// The landing page is embedded as a string constant so it always loads,
/// whether NeetMode is run via `swift run` or from a hand-assembled .app bundle
/// (no resource-bundle lookup that could fail at runtime).
///
/// A standalone, identical copy lives at `web/index.html` for reference/editing.
let indexHTML = #"""
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>NeetMode</title>
<style>
  :root{
    --bg:#05030f;
    --purple:#b15cff;
    --purple-bright:#d7a3ff;
    --magenta:#ff5cf0;
    --cyan:#54e6ff;
    --green:#76ffb0;
    --ink:#e9dcff;
    color-scheme: dark;
  }
  *{box-sizing:border-box;margin:0;padding:0}
  html,body{height:100%}
  body{
    font-family:"Avenir Next Condensed","Helvetica Neue",-apple-system,sans-serif;
    color:var(--ink);
    background:
      radial-gradient(120% 90% at 50% -20%, rgba(177,92,255,.22) 0%, rgba(80,30,160,.07) 35%, rgba(5,3,15,0) 60%),
      radial-gradient(80% 60% at 50% 120%, rgba(84,230,255,.08), rgba(5,3,15,0) 60%),
      #05030f;
    min-height:100vh;display:grid;place-items:center;overflow:hidden;
    -webkit-font-smoothing:antialiased;
  }
  body::before{
    content:"";position:fixed;inset:0;pointer-events:none;
    background:
      repeating-linear-gradient(0deg, rgba(150,90,255,.04) 0 1px, transparent 1px 38px),
      repeating-linear-gradient(90deg, rgba(150,90,255,.04) 0 1px, transparent 1px 38px);
    -webkit-mask-image:radial-gradient(120% 100% at 50% 50%, #000 30%, transparent 80%);
            mask-image:radial-gradient(120% 100% at 50% 50%, #000 30%, transparent 80%);
  }
  body::after{
    content:"";position:fixed;inset:0;pointer-events:none;
    box-shadow:inset 0 0 240px 40px rgba(0,0,0,.85);
  }

  .panel{
    position:relative;width:min(92vw,560px);padding:3px;
    --notch:22px;
    clip-path:polygon(var(--notch) 0,100% 0,100% calc(100% - var(--notch)),calc(100% - var(--notch)) 100%,0 100%,0 var(--notch));
    background:linear-gradient(160deg, rgba(177,92,255,.7), rgba(120,40,220,.2) 40%, rgba(84,230,255,.45));
    box-shadow:
      0 0 1px rgba(215,163,255,.6),
      0 0 12px rgba(177,92,255,.3),
      0 0 38px rgba(150,60,255,.18),
      inset 0 0 20px rgba(120,40,220,.26);
    animation:breathe 5.5s ease-in-out infinite;
  }
  @keyframes breathe{50%{box-shadow:0 0 2px rgba(215,163,255,.7),0 0 16px rgba(177,92,255,.42),0 0 50px rgba(150,60,255,.26),inset 0 0 24px rgba(120,40,220,.32)}}

  .frame{
    position:relative;
    --notch:20px;
    clip-path:polygon(var(--notch) 0,100% 0,100% calc(100% - var(--notch)),calc(100% - var(--notch)) 100%,0 100%,0 var(--notch));
    background:linear-gradient(180deg, rgba(20,8,42,.96), rgba(10,5,26,.98));
    padding:30px 34px 28px;
  }
  .frame::before{
    content:"";position:absolute;inset:9px;pointer-events:none;
    --notch:14px;
    clip-path:polygon(var(--notch) 0,100% 0,100% calc(100% - var(--notch)),calc(100% - var(--notch)) 100%,0 100%,0 var(--notch));
    border:1px solid rgba(84,230,255,.28);
    box-shadow:inset 0 0 12px rgba(84,230,255,.07);
  }

  .corner{position:absolute;width:26px;height:26px;border:2px solid var(--purple-bright);
    filter:drop-shadow(0 0 3px rgba(177,92,255,.6));z-index:3}
  .corner.tl{top:6px;left:6px;border-right:0;border-bottom:0}
  .corner.tr{top:6px;right:6px;border-left:0;border-bottom:0}
  .corner.bl{bottom:6px;left:6px;border-right:0;border-top:0}
  .corner.br{bottom:6px;right:6px;border-left:0;border-top:0}

  .titlebar{display:flex;align-items:center;justify-content:center;gap:14px;margin-bottom:10px}
  .titlebar i{height:1px;flex:1;background:linear-gradient(90deg,transparent,var(--purple),transparent);box-shadow:0 0 4px rgba(177,92,255,.5)}
  .titlebar span{font-size:12px;letter-spacing:.7em;color:var(--purple-bright);text-shadow:0 0 6px rgba(177,92,255,.5);padding-left:.7em}

  h1.status{
    text-align:center;font-size:46px;font-weight:800;letter-spacing:.18em;
    color:#efe6ff;text-shadow:0 0 10px rgba(177,92,255,.45),0 0 24px rgba(255,92,240,.22);
    margin-bottom:16px;
  }

  .stats{display:flex;gap:10px;justify-content:center;margin-bottom:18px;flex-wrap:wrap}
  .stats .chip{font-size:13px;letter-spacing:.12em;color:var(--cyan);
    border:1px solid rgba(84,230,255,.28);border-radius:4px;padding:5px 12px;
    background:rgba(84,230,255,.05);box-shadow:0 0 8px rgba(84,230,255,.08) inset}
  .stats .chip b{color:#fff;font-weight:700;text-shadow:0 0 6px rgba(84,230,255,.5)}

  .sec{font-size:12px;letter-spacing:.42em;color:var(--purple-bright);
    text-shadow:0 0 6px rgba(177,92,255,.4);text-align:center;margin:6px 0 14px}

  .durations{display:grid;grid-template-columns:repeat(3,1fr);gap:14px;margin-bottom:22px}
  .durations button{
    cursor:pointer;position:relative;padding:18px 0 14px;border-radius:6px;
    background:linear-gradient(180deg, rgba(120,50,210,.16), rgba(40,15,80,.22));
    border:1.5px solid rgba(177,92,255,.45);color:var(--ink);
    box-shadow:0 0 10px rgba(150,60,255,.1) inset;
    transition:transform .12s, border-color .15s, box-shadow .2s, color .15s;
  }
  .durations button b{display:block;font-size:30px;font-weight:800;letter-spacing:.04em;
    color:#fff;text-shadow:0 0 8px rgba(177,92,255,.55)}
  .durations button span{display:block;font-size:11px;letter-spacing:.4em;margin-top:3px;opacity:.7}
  .durations button:hover{transform:translateY(-3px);border-color:var(--purple-bright);
    box-shadow:0 0 14px rgba(177,92,255,.28), 0 0 12px rgba(150,60,255,.16) inset}
  .durations button.sel{
    border-color:var(--green);color:#fff;
    background:linear-gradient(180deg, rgba(118,255,176,.14), rgba(40,15,80,.22));
    box-shadow:0 0 16px rgba(118,255,176,.32), 0 0 14px rgba(118,255,176,.14) inset}
  .durations button.sel b{text-shadow:0 0 10px rgba(118,255,176,.7)}

  #start{
    width:100%;cursor:pointer;padding:16px;border:0;border-radius:6px;
    font-size:16px;font-weight:800;letter-spacing:.3em;color:#fff;
    --notch:12px;
    clip-path:polygon(var(--notch) 0,100% 0,100% calc(100% - var(--notch)),calc(100% - var(--notch)) 100%,0 100%,0 var(--notch));
    background:linear-gradient(110deg, #7a25e0, #b15cff 45%, #ff5cf0);
    box-shadow:0 0 14px rgba(177,92,255,.4),0 0 32px rgba(255,92,240,.2),inset 0 0 14px rgba(255,255,255,.12);
    text-shadow:0 0 8px rgba(255,255,255,.4);
    transition:transform .12s, box-shadow .2s, opacity .2s, filter .2s;
  }
  #start .play{margin-right:.5em}
  #start:hover:not(:disabled){transform:translateY(-2px);filter:brightness(1.1);
    box-shadow:0 0 22px rgba(177,92,255,.6),0 0 46px rgba(255,92,240,.34),inset 0 0 18px rgba(255,255,255,.18)}
  #start:disabled{opacity:.35;cursor:not-allowed;filter:grayscale(.3)}

  #status{min-height:18px;text-align:center;margin-top:16px;font-size:13px;letter-spacing:.15em;
    color:var(--green);text-shadow:0 0 8px rgba(118,255,176,.45)}
  .note{text-align:center;margin-top:10px;font-size:11px;letter-spacing:.2em;color:rgba(216,163,255,.5)}
</style>
</head>
<body>
  <div class="panel">
    <span class="corner tl"></span><span class="corner tr"></span>
    <span class="corner bl"></span><span class="corner br"></span>
    <div class="frame">
      <div class="titlebar"><i></i><span>SYSTEM</span><i></i></div>
      <h1 class="status">STATUS</h1>

      <div class="stats">
        <div class="chip">USER&nbsp;·&nbsp;<b>NeetMode</b></div>
        <div class="chip">PROTOCOL&nbsp;·&nbsp;<b>Focus Lock</b></div>
      </div>

      <div class="sec">SELECT FOCUS DURATION</div>
      <div class="durations" id="durations">
        <button data-min="15"><b>15</b><span>MIN</span></button>
        <button data-min="30"><b>30</b><span>MIN</span></button>
        <button data-min="60"><b>60</b><span>MIN</span></button>
      </div>

      <button id="start" disabled><span class="play">▶</span>INITIATE FOCUS</button>
      <p id="status"></p>
      <p class="note">ONLY NEETCODE IS ACCESSIBLE WHILE THE SESSION IS ACTIVE</p>
    </div>
  </div>

<script>
  let selected = null;
  const startBtn = document.getElementById('start');
  const status = document.getElementById('status');

  document.querySelectorAll('#durations button').forEach(function (b) {
    b.addEventListener('click', function () {
      document.querySelectorAll('#durations button').forEach(function (x) { x.classList.remove('sel'); });
      b.classList.add('sel');
      selected = b.dataset.min;
      startBtn.disabled = false;
    });
  });

  startBtn.addEventListener('click', function () {
    if (!selected) return;
    var bridge = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.neetmode;
    if (!bridge) {
      status.textContent = 'Open this inside the NeetMode app to start.';
      return;
    }
    startBtn.disabled = true;
    status.textContent = 'INITIATING — ' + selected + ' MIN LOCK';
    bridge.postMessage({ action: 'start', minutes: Number(selected) });
  });
</script>
</body>
</html>
"""#
