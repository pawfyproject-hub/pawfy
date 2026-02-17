/* REDFINGER TARGETED CLICKER - FINAL VERSION
   Target: Singapore & 10.0
   Safety: Randomized Interval (0.5s - 1.5s)
   Platform: Kiwi Browser (Optimized for Background)
*/

(function() {
    let count = 0;
    console.clear();
    console.log("%c🚀 BOT REDFINGER AKTIF", "background: #004d40; color: #ccff00; padding: 10px; font-weight: bold; border-radius: 5px;");
    console.log("%c🎯 Target: Singapore 10.0\n🛡️ Mode: Safe Random (0.5s - 1.5s)\n📱 Info: Pantau angka di Judul Tab saat TikTok-an.", "color: #e0e0e0;");

    function runTurbo() {
        try {
            // 1. MEMASTIKAN PILIHAN BENAR (Singapore & 10.0)
            const attributes = document.querySelectorAll('.attr-name');
            attributes.forEach(attr => {
                const text = attr.innerText.trim();
                if (text === "Singapore" || text === "10.0") {
                    // Hanya klik jika elemen induknya tidak memiliki class 'active'
                    if (!attr.parentElement.classList.contains('active')) {
                        attr.click();
                    }
                }
            });

            // 2. MENCARI TOMBOL GANTI YANG SPESIFIK (Class Submit)
            // Menggunakan selector gabungan agar tidak salah klik kata "ganti" yang lain
            const btnGanti = document.querySelector('button.submit, .button-native.submit, button[slot="fixed"].submit');

            if (btnGanti) {
                // Simulasi klik MouseEvent (Lebih kuat menembus proteksi sistem)
                const clickEvent = new MouseEvent("click", {
                    view: window,
                    bubbles: true,
                    cancelable: true
                });
                
                btnGanti.dispatchEvent(clickEvent);
                count++;

                // 3. UPDATE JUDUL TAB (Sangat penting untuk pantauan saat pindah apps)
                document.title = `🔥 [${count}] SG-10.0`;

                // Log setiap 5 klik agar Console tidak terlalu penuh (hemat RAM)
                if (count % 5 === 0) {
                    console.log(`%c✅ Berhasil klik ke-${count}`, "color: #00ff00;");
                }
            }
        } catch (err) {
            console.error("Bot mengalami gangguan, mencoba mengulang...", err);
        }

        // 4. SET JEDA ACAK (500ms s/d 1500ms)
        const randomDelay = Math.floor(Math.random() * (1500 - 500 + 1)) + 500;
        setTimeout(runTurbo, randomDelay);
    }

    // Jalankan bot
    runTurbo();

    // Fungsi untuk menghentikan bot jika diperlukan
    window.stopBot = () => {
        const id = window.setTimeout(function() {}, 0);
        while (id--) window.clearTimeout(id);
        console.log("%c🛑 BOT DIHENTIKAN.", "background: red; color: white; padding: 5px;");
    };
})();
