document.addEventListener('DOMContentLoaded', function() {
    // Animar las barras de progreso de las habilidades
    const skillBars = document.querySelectorAll('.progress-bar');
    skillBars.forEach(bar => {
        const progress = bar.querySelector('.progress');
        const value = parseInt(bar.dataset.progress);
        progress.style.width = `${value}%`;
    });

    // Opcional: Agregar funcionalidad de desplazamiento suave a los enlaces de navegación
    const navLinks = document.querySelectorAll('header a[href^="#"], .hero a[href^="#"]');
    navLinks.forEach(link => {
        link.addEventListener('click', function(e) {
            e.preventDefault();
            const targetId = this.getAttribute('href');
            const targetElement = document.querySelector(targetId);
            if (targetElement) {
                window.scrollTo({
                    top: targetElement.offsetTop - 60, // Ajusta el desplazamiento si tienes una barra de navegación fija
                    behavior: 'smooth'
                });
            }
        });
    });

    // Fondo animado del header
    const heroBackground = document.querySelector('.hero-background');
    const numLines = 50; // Número de líneas a generar
    const animationSpeed = 0.05; // Velocidad de la animación (ajusta según sea necesario)
    const lineColors = ['rgba(255, 255, 255, 0.3)', 'rgba(255, 255, 255, 0.5)']; // Colores de las líneas

    function createLine() {
        const line = document.createElement('div');
        line.classList.add('animated-line');
        const startX = Math.random() * 100;
        const startY = Math.random() * 100;
        const length = Math.random() * 30 + 10; // Longitud aleatoria
        const angle = Math.random() * 360; // Ángulo aleatorio
        const color = lineColors[Math.floor(Math.random() * lineColors.length)];

        line.style.position = 'absolute';
        line.style.width = `${length}px`;
        line.style.height = '1px';
        line.style.backgroundColor = color;
        line.style.transformOrigin = 'left center';
        line.style.transform = `translate(${startX}vw, ${startY}vh) rotate(${angle}deg)`;
        line.style.opacity = 0;
        line.life = 0; // Tiempo de vida de la línea
        line.maxLife = Math.random() * 100 + 50; // Duración aleatoria antes de desaparecer

        heroBackground.appendChild(line);
        return line;
    }

    const lines = [];
    for (let i = 0; i < numLines; i++) {
        lines.push(createLine());
    }

    function animateLines() {
        lines.forEach(line => {
            line.life += 1;
            const speedX = Math.cos(parseFloat(line.style.transform.split('rotate(')[1]) * Math.PI / 180) * animationSpeed;
            const speedY = Math.sin(parseFloat(line.style.transform.split('rotate(')[1]) * Math.PI / 180) * animationSpeed;

            const currentTranslate = line.style.transform.split('translate(')[1].split(')')[0].split(',');
            let translateX = parseFloat(currentTranslate[0].replace('vw', '')) + speedX;
            let translateY = parseFloat(currentTranslate[1].replace('vh', '')) + speedY;

            line.style.transform = `translate(${translateX}vw, ${translateY}vh) rotate(${parseFloat(line.style.transform.split('rotate(')[1])}deg)`;
            line.style.opacity = Math.min(1, line.life / 30); // Aparecer gradualmente
            line.style.backgroundColor = line.style.backgroundColor.replace(/, \d\.\d+\)/, `, ${Math.max(0, 1 - line.life / line.maxLife)})`); // Desvanecer gradualmente

            if (line.life > line.maxLife) {
                line.remove();
                const index = lines.indexOf(line);
                if (index > -1) {
                    lines.splice(index, 1);
                }
                lines.push(createLine()); // Reemplazar la línea vieja con una nueva
            }
        });
        requestAnimationFrame(animateLines);
    }

    animateLines();
});