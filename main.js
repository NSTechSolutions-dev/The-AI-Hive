class Particle {
  constructor(canvas) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.x = Math.random() * canvas.width;
    this.y = Math.random() * canvas.height;
    this.vx = (Math.random() - 0.5) * 0.3;
    this.vy = (Math.random() - 0.5) * 0.3;
    this.radius = Math.random() * 1.2 + 0.5;
    this.alpha = Math.random() * 0.4 + 0.1;
  }

  update() {
    this.x += this.vx;
    this.y += this.vy;

    if (this.x < 0 || this.x > this.canvas.width) this.vx *= -1;
    if (this.y < 0 || this.y > this.canvas.height) this.vy *= -1;
  }

  draw() {
    this.ctx.beginPath();
    this.ctx.arc(this.x, this.y, this.radius, 0, Math.PI * 2);
    this.ctx.fillStyle = `rgba(245, 158, 11, ${this.alpha})`;
    this.ctx.fill();
  }
}

class ParticleNetwork {
  constructor() {
    this.canvas = document.getElementById('bg-canvas');
    if (!this.canvas) return;
    this.ctx = this.canvas.getContext('2d');
    this.particles = [];
    this.particleCount = 50;

    this.resize();
    window.addEventListener('resize', () => this.resize());

    for (let i = 0; i < this.particleCount; i++) {
      this.particles.push(new Particle(this.canvas));
    }

    this.animate();
  }

  resize() {
    this.canvas.width = window.innerWidth;
    this.canvas.height = window.innerHeight;
  }

  animate() {
    this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);

    this.particles.forEach(p => {
      p.update();
      p.draw();
    });

    for (let i = 0; i < this.particles.length; i++) {
      for (let j = i + 1; j < this.particles.length; j++) {
        const dx = this.particles[i].x - this.particles[j].x;
        const dy = this.particles[i].y - this.particles[j].y;
        const dist = Math.sqrt(dx * dx + dy * dy);

        if (dist < 130) {
          this.ctx.beginPath();
          this.ctx.moveTo(this.particles[i].x, this.particles[i].y);
          this.ctx.lineTo(this.particles[j].x, this.particles[j].y);
          this.ctx.strokeStyle = `rgba(245, 158, 11, ${0.12 * (1 - dist / 130)})`;
          this.ctx.lineWidth = 0.5;
          this.ctx.stroke();
        }
      }
    }

    requestAnimationFrame(() => this.animate());
  }
}

// Dynamic Loading Sequence Handler
function runDynamicLoader(callback) {
  const progressEl = document.getElementById('loaderProgress');
  const statusEl = document.getElementById('loaderStatusText');
  const screenEl = document.getElementById('loader-screen');

  if (!progressEl) {
    if (callback) callback();
    return;
  }

  const steps = [
    { text: "Building Awesomeness .", pct: 25, delay: 400 },
    { text: "Building Awesomeness . .", pct: 55, delay: 500 },
    { text: "Building Awesomeness . . .", pct: 80, delay: 400 },
    { text: "Building Awesomeness [ Ready ]", pct: 100, delay: 450 }
  ];

  let currentStepIndex = 0;

  function nextStep() {
    if (currentStepIndex >= steps.length) {
      setTimeout(() => {
        screenEl.style.opacity = '0';
        screenEl.style.visibility = 'hidden';
        if (callback) callback();
      }, 350);
      return;
    }

    const step = steps[currentStepIndex];
    statusEl.innerText = step.text;
    progressEl.style.width = `${step.pct}%`;

    currentStepIndex++;
    setTimeout(nextStep, step.delay);
  }

  nextStep();
}

// App Initialization
document.addEventListener('DOMContentLoaded', () => {
  new ParticleNetwork();

  runDynamicLoader(() => {
    console.log("AIHive landing page fully loaded.");
  });

  // Handle Enquiry Form Submission
  const enquiryForm = document.getElementById('enquiryForm');
  if (enquiryForm) {
    enquiryForm.addEventListener('submit', (e) => {
      e.preventDefault();
      const name = document.getElementById('enquiryName').value;
      const email = document.getElementById('enquiryEmail').value;

      if (!name || !email) return;

      const submitBtn = enquiryForm.querySelector('.btn-submit');
      const originalText = submitBtn.innerText;
      submitBtn.innerText = 'Sending...';
      submitBtn.disabled = true;

      setTimeout(() => {
        submitBtn.innerText = 'Sent Successfully!';
        submitBtn.style.background = '#10b981';
        submitBtn.style.color = '#fff';
        enquiryForm.reset();

        setTimeout(() => {
          submitBtn.innerText = originalText;
          submitBtn.style.background = '';
          submitBtn.style.color = '';
          submitBtn.disabled = false;
        }, 3000);
      }, 1500);
    });
  }
});
