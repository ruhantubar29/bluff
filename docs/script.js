const REPO = "ruhantubar29/bluff";
const RELEASES_URL = `https://github.com/${REPO}/releases`;
const MAX_SCREENSHOTS = 30;
const EXTENSIONS = ["png", "jpg", "jpeg", "webp"];

const $ = (id) => document.getElementById(id);
const track = $("screenshotTrack");
const dots = $("dots");
const prev = $("prevButton");
const next = $("nextButton");
const stage = $("heroStage");
const toast = $("toast");


/* ---------- screenshots (ss1, ss2, ... in /images) ---------- */

function probe(src) {
    return new Promise((resolve) => {
        const img = new Image();
        img.onload = () => resolve(true);
        img.onerror = () => resolve(false);
        img.src = src;
    });
}

async function findScreenshot(i) {
    for (const ext of EXTENSIONS) {
        const src = `images/ss${i}.${ext}`;
        if (await probe(src)) return src;
    }
    return null;
}

async function findScreenshots() {
    const indexes = Array.from({ length: MAX_SCREENSHOTS }, (_, i) => i + 1);
    const found = await Promise.all(indexes.map(findScreenshot));
    return found.filter(Boolean);
}

function renderStage(list) {
    if (!list.length) {
        stage.innerHTML = '<img class="stage-icon" src="images/icon.png" alt="">';
        stage.classList.add("ready");
        return;
    }

    // center = first screenshot, then left, then right
    const roles = ["center", "left", "right"];
    stage.innerHTML = list.slice(0, 3)
        .map((src, i) => `<div class="ph ph-${roles[i]}"><img src="${src}" alt=""></div>`)
        .join("");

    requestAnimationFrame(() => stage.classList.add("ready"));
}

function renderGallery(list) {
    if (!list.length) {
        track.innerHTML = '<div class="no-screenshots">Screenshots coming soon.</div>';
        dots.innerHTML = "";
        prev.disabled = true;
        next.disabled = true;
        return;
    }

    track.innerHTML = "";
    dots.innerHTML = "";

    list.forEach((src, i) => {
        const img = document.createElement("img");
        img.className = "screenshot";
        img.src = src;
        img.alt = `BLUFFBD screenshot ${i + 1}`;
        img.loading = "lazy";
        track.appendChild(img);

        const dot = document.createElement("button");
        dot.type = "button";
        dot.className = "dot";
        dot.setAttribute("aria-label", `Screenshot ${i + 1}`);
        dot.onclick = () => track.children[i].scrollIntoView({ behavior: "smooth", inline: "start", block: "nearest" });
        dots.appendChild(dot);
    });

    const update = () => {
        const pad = parseFloat(getComputedStyle(track).paddingLeft) || 0;
        const items = [...track.children];
        let best = 0;
        let bestDist = Infinity;

        items.forEach((el, i) => {
            const dist = Math.abs(el.offsetLeft - pad - track.scrollLeft);
            if (dist < bestDist) { bestDist = dist; best = i; }
        });

        [...dots.children].forEach((d, i) => d.classList.toggle("active", i === best));
        prev.disabled = track.scrollLeft <= 4;
        next.disabled = track.scrollLeft + track.clientWidth >= track.scrollWidth - 4;
    };

    const step = () => track.children[0].getBoundingClientRect().width + 18;
    prev.onclick = () => track.scrollBy({ left: -step(), behavior: "smooth" });
    next.onclick = () => track.scrollBy({ left: step(), behavior: "smooth" });
    track.addEventListener("scroll", () => requestAnimationFrame(update), { passive: true });
    window.addEventListener("resize", update);
    update();
}

findScreenshots().then((list) => {
    renderStage(list);
    renderGallery(list);
});


/* ---------- latest release info from GitHub ---------- */

function setInstall(url, note) {
    document.querySelectorAll(".js-install").forEach((a) => (a.href = url));
    if (note) document.querySelectorAll(".install-note").forEach((n) => (n.textContent = note));
}

async function loadRelease() {
    try {
        const res = await fetch(`https://api.github.com/repos/${REPO}/releases/latest`, {
            headers: { Accept: "application/vnd.github+json" },
        });

        if (res.status === 404) {
            // no release published yet
            setInstall(RELEASES_URL, "Coming soon");
            return;
        }
        if (!res.ok) return; // rate-limited etc: keep the default link

        const rel = await res.json();
        const apk = (rel.assets || []).find((a) => /\.apk$/i.test(a.name));

        setInstall(apk ? apk.browser_download_url : rel.html_url);

        if (rel.tag_name) $("relVersion").textContent = rel.tag_name;

        const date = rel.published_at
            ? new Date(rel.published_at).toLocaleDateString("en", { month: "short", year: "numeric" })
            : "";
        const size = apk ? `${(apk.size / 1048576).toFixed(1)} MB` : "";

        if (size || date) {
            $("relSize").textContent = size || "—";
            $("relDate").textContent = date || "—";
            $("relFacts").hidden = false;
        }

        const line = [rel.tag_name, size, date && `Updated ${date}`].filter(Boolean).join("  ·  ");
        if (line) {
            $("releaseLine").textContent = line;
            $("releaseLine").hidden = false;
        }
    } catch (e) {
        /* offline: keep default links */
    }
}

loadRelease();


/* ---------- share ---------- */

$("heroShareButton").addEventListener("click", async () => {
    const data = { title: "BLUFFBD", text: "The ultimate collection of classic party games with friends.", url: location.href };

    try {
        if (navigator.share) {
            await navigator.share(data);
        } else {
            await navigator.clipboard.writeText(location.href);
            toast.classList.add("on");
            setTimeout(() => toast.classList.remove("on"), 1800);
        }
    } catch (e) { /* cancelled */ }
});


/* ---------- mobile install dock ---------- */

const dock = $("dock");
new IntersectionObserver(([entry]) => {
    dock.classList.toggle("on", !entry.isIntersecting);
}, { threshold: 0.05 }).observe($("hero"));