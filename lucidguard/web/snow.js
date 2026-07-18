(() => {
  const canvas = document.getElementById('snow');
  if (!canvas) return;
  const ctx = canvas.getContext('2d');
  let flakes = [];
  let running = true;
  let raf = 0;
  let palette = 'orange';

  const PALETTES = {
    orange: [18, 45],   // hue range
    purple: [265, 40],
    teal: [165, 35],
    rose: [340, 30],
    gold: [40, 25]
  };

  function hueBase() {
    const p = PALETTES[palette] || PALETTES.orange;
    return p[0] + Math.random() * p[1];
  }

  function resize() {
    canvas.width = window.innerWidth * devicePixelRatio;
    canvas.height = window.innerHeight * devicePixelRatio;
    canvas.style.width = window.innerWidth + 'px';
    canvas.style.height = window.innerHeight + 'px';
    ctx.setTransform(devicePixelRatio, 0, 0, devicePixelRatio, 0, 0);
  }

  function spawn(count) {
    flakes = [];
    for (let i = 0; i < count; i++) {
      flakes.push({
        x: Math.random() * window.innerWidth,
        y: Math.random() * window.innerHeight,
        r: Math.random() * 2.4 + 0.6,
        s: Math.random() * 0.9 + 0.35,
        drift: Math.random() * 0.8 - 0.4,
        a: Math.random() * 0.55 + 0.25,
        hue: hueBase()
      });
    }
  }

  function frame() {
    if (!running) return;
    ctx.clearRect(0, 0, window.innerWidth, window.innerHeight);
    for (const f of flakes) {
      f.y += f.s;
      f.x += f.drift + Math.sin(f.y * 0.01) * 0.25;
      if (f.y > window.innerHeight + 4) {
        f.y = -6;
        f.x = Math.random() * window.innerWidth;
        f.hue = hueBase();
      }
      if (f.x > window.innerWidth + 4) f.x = -4;
      if (f.x < -4) f.x = window.innerWidth + 4;
      ctx.beginPath();
      ctx.fillStyle = `hsla(${f.hue}, 90%, 62%, ${f.a})`;
      ctx.shadowColor = `hsla(${f.hue}, 95%, 58%, 0.55)`;
      ctx.shadowBlur = 8;
      ctx.arc(f.x, f.y, f.r, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.shadowBlur = 0;
    raf = requestAnimationFrame(frame);
  }

  window.LucidSnow = {
    setEnabled(on) {
      running = !!on;
      canvas.style.opacity = on ? '1' : '0';
      if (on) {
        cancelAnimationFrame(raf);
        frame();
      } else {
        cancelAnimationFrame(raf);
        ctx.clearRect(0, 0, window.innerWidth, window.innerHeight);
      }
    },
    setPalette(name) {
      palette = name || 'orange';
      spawn(flakes.length || Math.min(120, Math.floor(window.innerWidth / 12)));
    }
  };

  window.addEventListener('resize', () => {
    resize();
    spawn(Math.min(120, Math.floor(window.innerWidth / 12)));
  });

  resize();
  spawn(Math.min(120, Math.floor(window.innerWidth / 12)));
  frame();
})();
