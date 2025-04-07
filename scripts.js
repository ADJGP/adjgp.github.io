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
    const numLines = 50; // Número de líneas a generar
    const animationSpeed = 0.5; // Velocidad de la animación (ajusta según sea necesario)
    const neonColors = ['#FFFF00', '#00FFFF', '#FF00FF']; // Amarillo, Cian (Azul Neón), Magenta (Rojo Neón)

    function createLine() {
        const line = document.createElement('div');
        line.classList.add('animated-line');
        const startX = Math.random() * 100;
        const startY = Math.random() * 100;
        const length = Math.random() * 40 + 10; // Longitud aleatoria
        const angle = Math.random() * 360; // Ángulo aleatorio
        const color = neonColors[Math.floor(Math.random() * neonColors.length)];
        const opacity = Math.random() * 0.4 + 0.6; // Opacidad aleatoria (más bien opaco)
        const life = 0;
        const maxLife = Math.random() * 150 + 100; // Duración antes de desaparecer

        line.style.position = 'absolute';
        line.style.width = `${length}px`;
        line.style.height = '1px';
        line.style.backgroundColor = color;
        line.style.opacity = opacity;
        line.style.transformOrigin = 'left center';
        line.style.transform = `translate(${startX}vw, ${startY}vh) rotate(${angle}deg)`;
        line.life = life;
        line.maxLife = maxLife;

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
            line.style.opacity = Math.max(0, 1 - line.life / line.maxLife); // Desvanecer gradualmente

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

    const portfolioSection = document.getElementById('portafolio');
    const portfolioBackground = document.createElement('div');
    portfolioBackground.classList.add('portfolio-background');
    portfolioSection.appendChild(portfolioBackground);

    const numPortfolioLines = 40; // Número de líneas para el portafolio
    const portfolioAnimationSpeed = 0.3; // Velocidad para el portafolio (ajusta si es necesario)
    const portfolioLineColor = 'rgba(0, 0, 0, 1)'; // Líneas negras con opacidad

    const portfolioLines = [];
    for (let i = 0; i < numPortfolioLines; i++) {
        portfolioLines.push(createPortfolioLine());
    }

    function createPortfolioLine() {
        const line = document.createElement('div');
        line.classList.add('animated-portfolio-line');
        const startX = Math.random() * 100;
        const startY = Math.random() * 100;
        const length = Math.random() * 30 + 10;
        const angle = Math.random() * 360;
        const opacity = Math.random() * 0.3 + 0.2; // Opacidad para las líneas negras
        const life = 0;
        const maxLife = Math.random() * 120 + 80;

        line.style.position = 'absolute';
        line.style.width = `${length}px`;
        line.style.height = '1px';
        line.style.backgroundColor = portfolioLineColor;
        line.style.opacity = opacity;
        line.style.transformOrigin = 'left center';
        line.style.transform = `translate(${startX}vw, ${startY}vh) rotate(${angle}deg)`;
        line.life = life;
        line.maxLife = maxLife;

        portfolioBackground.appendChild(line);
        return line;
    }

    function animatePortfolioLines() {
        portfolioLines.forEach(line => {
            line.life += 1;
            const speedX = Math.cos(parseFloat(line.style.transform.split('rotate(')[1]) * Math.PI / 180) * portfolioAnimationSpeed;
            const speedY = Math.sin(parseFloat(line.style.transform.split('rotate(')[1]) * Math.PI / 180) * portfolioAnimationSpeed;

            const currentTranslate = line.style.transform.split('translate(')[1].split(')')[0].split(',');
            let translateX = parseFloat(currentTranslate[0].replace('vw', '')) + speedX;
            let translateY = parseFloat(currentTranslate[1].replace('vh', '')) + speedY;

            line.style.transform = `translate(${translateX}vw, ${translateY}vh) rotate(${parseFloat(line.style.transform.split('rotate(')[1])}deg)`;
            line.style.opacity = Math.max(0, 1 - line.life / line.maxLife);

            if (line.life > line.maxLife) {
                line.remove();
                const index = portfolioLines.indexOf(line);
                if (index > -1) {
                    portfolioLines.splice(index, 1);
                }
                portfolioLines.push(createPortfolioLine());
            }
        });
        requestAnimationFrame(animatePortfolioLines);
    }

    animatePortfolioLines();
    
    const carouselContainer = document.querySelector('.skills-carousel-container');
    const carousel = document.querySelector('.skills-carousel');
    const prevButton = document.querySelector('.carousel-button.prev');
    const nextButton = document.querySelector('.carousel-button.next');
    const skillIcons = document.querySelectorAll('.skill-icon');
    const iconWidth = skillIcons[0].offsetWidth + (parseInt(getComputedStyle(skillIcons[0]).marginRight) || 0) * 2; // Ancho de cada icono con márgenes
    let currentIndex = 0;
    
    function scrollToItem(index) {
            const translateX = -index * iconWidth;
            carousel.style.transform = `translateX(${translateX}px)`;
        }
    
    function nextSlide() {
            if (currentIndex < skillIcons.length - 1) {
                currentIndex++;
                scrollToItem(currentIndex);
            }
        }
    
    function prevSlide() {
            if (currentIndex > 0) {
                currentIndex--;
                scrollToItem(currentIndex);
            }
        }
    
    nextButton.addEventListener('click', nextSlide);
    prevButton.addEventListener('click', prevSlide);
    
    // Opcional: Hacer que el carrusel sea infinito (vuelve al principio/final)
        
        /*function nextSlideInfinite() {
            currentIndex = (currentIndex + 1) % skillIcons.length;
            scrollToItem(currentIndex);
        }
    
        function prevSlideInfinite() {
            currentIndex = (currentIndex - 1 + skillIcons.length) % skillIcons.length;
            scrollToItem(currentIndex);
        }
    
        nextButton.addEventListener('click', nextSlideInfinite);
        prevButton.addEventListener('click', prevSlideInfinite);
    
        // Opcional: Desplazamiento automático
        function autoSlide() {
            setInterval(nextSlideInfinite, 3000); // Cambia de slide cada 3 segundos
        }
        autoSlide();*/

});