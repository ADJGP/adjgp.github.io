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

    const heroBackground = document.querySelector('.hero-background');
    const numShapes = 30; // Número de figuras a generar
    const animationSpeed = 0.8; // Velocidad de la animación (ajusta según sea necesario)
    const neonColors = ['#FFFF00', '#00FFFF', '#FF00FF']; // Amarillo, Cian (Azul Neón), Magenta (Rojo Neón)

    function createShape() {
        const shape = document.createElement('div');
        shape.classList.add('animated-shape');
        const type = Math.random() < 0.5 ? 'circle' : 'square'; // Aleatoriamente círculo o cuadrado
        const size = Math.random() * 30 + 10; // Tamaño aleatorio
        const startX = Math.random() * 100;
        const startY = Math.random() * 100;
        const color = neonColors[Math.floor(Math.random() * neonColors.length)];
        const opacity = Math.random() * 0.5 + 0.5; // Opacidad aleatoria (más bien opaco)
        const duration = Math.random() * 5 + 3; // Duración de la animación en segundos

        shape.style.position = 'absolute';
        shape.style.width = `${size}px`;
        shape.style.height = `${size}px`;
        shape.style.backgroundColor = color;
        shape.style.opacity = opacity;
        shape.style.borderRadius = type === 'circle' ? '50%' : '0';
        shape.style.left = `${startX}vw`;
        shape.style.top = `${startY}vh`;
        shape.style.pointerEvents = 'none'; // Para que no interfieran con los clics

        // Animación de movimiento aleatorio (keyframe en CSS)
        const directionX = Math.random() < 0.5 ? '' : '-';
        const directionY = Math.random() < 0.5 ? '' : '-';
        const speedFactor = Math.random() * 0.5 + 0.5;

        shape.style.animation = `float ${duration}s infinite alternate ${directionX}${Math.random() * 20 + 10}%, ${directionY}${Math.random() * 20 + 10}%`;
        heroBackground.appendChild(shape);
        return shape;
    }

    const shapes = [];
    for (let i = 0; i < numShapes; i++) {
        shapes.push(createShape());
    }
});