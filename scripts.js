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
});