// StarCraftKit Landing Page JavaScript

// Code tab switching
document.addEventListener('DOMContentLoaded', function() {
    // Handle code tabs
    const codeTabs = document.querySelectorAll('.code-tab');
    const cliCode = document.getElementById('cli-code');
    const swiftCode = document.getElementById('swift-code');
    
    codeTabs.forEach(tab => {
        tab.addEventListener('click', function() {
            // Remove active class from all tabs
            codeTabs.forEach(t => t.classList.remove('active'));
            // Add active class to clicked tab
            this.classList.add('active');
            
            // Show/hide code blocks
            if (this.dataset.tab === 'cli') {
                cliCode.classList.remove('hidden');
                swiftCode.classList.add('hidden');
            } else {
                swiftCode.classList.remove('hidden');
                cliCode.classList.add('hidden');
            }
        });
    });
    
    // Handle CLI demo tabs
    const cliTabs = document.querySelectorAll('.cli-tab');
    const cliOutputs = document.querySelectorAll('.cli-output');
    
    cliTabs.forEach(tab => {
        tab.addEventListener('click', function() {
            // Remove active class from all tabs and outputs
            cliTabs.forEach(t => t.classList.remove('active'));
            cliOutputs.forEach(o => o.classList.remove('active'));
            
            // Add active class to clicked tab
            this.classList.add('active');
            
            // Show corresponding output
            const demoId = `demo-${this.dataset.demo}`;
            const output = document.getElementById(demoId);
            if (output) {
                output.classList.add('active');
            }
        });
    });
    
    // Smooth scrolling for navigation links
    const navLinks = document.querySelectorAll('a[href^="#"]');
    navLinks.forEach(link => {
        link.addEventListener('click', function(e) {
            e.preventDefault();
            const targetId = this.getAttribute('href').substring(1);
            const targetElement = document.getElementById(targetId);
            if (targetElement) {
                const offset = 80; // Navbar height
                const targetPosition = targetElement.offsetTop - offset;
                window.scrollTo({
                    top: targetPosition,
                    behavior: 'smooth'
                });
            }
        });
    });
    
    // Navbar scroll effect
    const navbar = document.querySelector('.navbar');
    let lastScroll = 0;
    
    window.addEventListener('scroll', function() {
        const currentScroll = window.pageYOffset;
        
        if (currentScroll > 100) {
            navbar.style.boxShadow = '0 2px 10px rgba(0, 0, 0, 0.1)';
        } else {
            navbar.style.boxShadow = 'none';
        }
        
        lastScroll = currentScroll;
    });
    
    // Terminal animation
    const terminalOutput = document.querySelector('.terminal-body .output');
    if (terminalOutput) {
        // Add typing effect for demo purposes
        terminalOutput.style.opacity = '0';
        setTimeout(() => {
            terminalOutput.style.opacity = '1';
            terminalOutput.style.transition = 'opacity 0.5s ease';
        }, 500);
    }
    
    // Intersection Observer for fade-in animations
    const observerOptions = {
        threshold: 0.1,
        rootMargin: '0px 0px -50px 0px'
    };
    
    const observer = new IntersectionObserver(function(entries) {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.style.opacity = '1';
                entry.target.style.transform = 'translateY(0)';
            }
        });
    }, observerOptions);
    
    // Observe feature cards and other elements
    const animatedElements = document.querySelectorAll('.feature-card, .cli-card, .install-option');
    animatedElements.forEach(el => {
        el.style.opacity = '0';
        el.style.transform = 'translateY(20px)';
        el.style.transition = 'opacity 0.5s ease, transform 0.5s ease';
        observer.observe(el);
    });
    
    // Add hover effects to terminal
    const terminal = document.querySelector('.terminal-window');
    if (terminal) {
        terminal.addEventListener('mouseenter', function() {
            this.style.transform = 'scale(1.02)';
            this.style.transition = 'transform 0.3s ease';
        });
        
        terminal.addEventListener('mouseleave', function() {
            this.style.transform = 'scale(1)';
        });
    }
    
    // Copy functionality for install commands
    const copyButtons = document.querySelectorAll('.copy-btn');
    copyButtons.forEach(btn => {
        btn.addEventListener('click', async function(e) {
            e.preventDefault();
            const command = this.parentElement.querySelector('code').textContent;
            try {
                await navigator.clipboard.writeText(command);
                const originalHTML = this.innerHTML;
                this.innerHTML = `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <polyline points="20 6 9 17 4 12"></polyline>
                </svg>`;
                setTimeout(() => {
                    this.innerHTML = originalHTML;
                }, 2000);
            } catch (err) {
                console.error('Failed to copy:', err);
            }
        });
    });
    
    // Copy code functionality (for future enhancement)
    const codeBlocks = document.querySelectorAll('.code-block');
    codeBlocks.forEach(block => {
        block.style.position = 'relative';
        
        // Create copy button
        const copyButton = document.createElement('button');
        copyButton.innerHTML = '📋';
        copyButton.className = 'copy-button';
        copyButton.style.cssText = `
            position: absolute;
            top: 0.5rem;
            right: 0.5rem;
            background: var(--bg-tertiary);
            border: 1px solid var(--border-color);
            border-radius: 4px;
            padding: 0.25rem 0.5rem;
            cursor: pointer;
            opacity: 0;
            transition: opacity 0.3s ease;
        `;
        
        block.appendChild(copyButton);
        
        // Show button on hover
        block.addEventListener('mouseenter', () => {
            copyButton.style.opacity = '1';
        });
        
        block.addEventListener('mouseleave', () => {
            copyButton.style.opacity = '0';
        });
        
        // Copy code on click
        copyButton.addEventListener('click', async () => {
            const code = block.querySelector('code').textContent;
            try {
                await navigator.clipboard.writeText(code);
                copyButton.innerHTML = '✅';
                setTimeout(() => {
                    copyButton.innerHTML = '📋';
                }, 2000);
            } catch (err) {
                console.error('Failed to copy code:', err);
            }
        });
    });
    
    // Dynamic year in footer
    const yearElement = document.querySelector('.footer-bottom p');
    if (yearElement) {
        const currentYear = new Date().getFullYear();
        yearElement.innerHTML = yearElement.innerHTML.replace('2025', currentYear);
    }
    
    // Platform-specific download suggestions
    const platform = navigator.platform.toLowerCase();
    const downloadLinks = document.querySelectorAll('.download-link');
    
    downloadLinks.forEach(link => {
        if ((platform.includes('mac') && link.textContent.includes('macOS')) ||
            (platform.includes('linux') && link.textContent.includes('Linux'))) {
            link.style.background = 'var(--sc2-blue)';
            link.style.color = 'white';
        }
    });
    
    // Detect OS and update quick start install command
    function detectOSAndUpdateInstall() {
        const installCommandEl = document.querySelector('.install-command-line');
        if (!installCommandEl) return;
        
        const userAgent = navigator.userAgent.toLowerCase();
        const platform = navigator.platform.toLowerCase();
        
        let installCommand = 'yay -S starcraft-cli'; // default to AUR
        
        // Check for macOS
        if (platform.includes('mac')) {
            installCommand = 'brew tap guitaripod/tap && brew install starcraft-cli';
        }
        
        installCommandEl.textContent = installCommand;
    }
    
    detectOSAndUpdateInstall();
});

// Theme detection and management
(function() {
    // This runs immediately to prevent flash of wrong theme
    const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
    
    // Apply theme class immediately if needed
    if (prefersDark) {
        document.documentElement.classList.add('dark-mode');
    }
    
    // Listen for theme changes
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', (e) => {
        if (e.matches) {
            document.documentElement.classList.add('dark-mode');
        } else {
            document.documentElement.classList.remove('dark-mode');
        }
    });
})();