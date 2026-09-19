const MAX_SCREENSHOTS = 30;


const screenshotTrack =
    document.getElementById("screenshotTrack");

const dots =
    document.getElementById("dots");

const prevButton =
    document.getElementById("prevButton");

const nextButton =
    document.getElementById("nextButton");


let screenshots = [];

let currentIndex = 0;



/*
    Check whether an image exists.
*/

function loadImage(src) {

    return new Promise((resolve, reject) => {

        const img = new Image();

        img.onload = () => resolve(img);

        img.onerror = reject;

        img.src = src;

    });

}



/*
    Automatically find:

        ss1
        ss2
        ss3
        ss4
        ...

    Supports:

        PNG
        JPG
        JPEG
        WEBP
*/

async function findScreenshots() {

    const found = [];


    for (
        let i = 1;
        i <= MAX_SCREENSHOTS;
        i++
    ) {

        const extensions = [
            "png",
            "jpg",
            "jpeg",
            "webp"
        ];


        for (const extension of extensions) {

            const src =
                `images/ss${i}.${extension}`;


            try {

                await loadImage(src);

                found.push(src);

                break;

            } catch (_) {

                // File doesn't exist.
            }

        }

    }


    return found;
}



/*
    Display screenshots.
*/

function renderScreenshots() {

    screenshotTrack.innerHTML = "";

    dots.innerHTML = "";


    if (screenshots.length === 0) {

        screenshotTrack.innerHTML = `
            <div class="no-screenshots">
                Upload&nbsp;
                <strong>
                    ss1.png, ss2.png, ss3.png…
                </strong>
                &nbsp;to docs/images/
            </div>
        `;

        prevButton.disabled = true;

        nextButton.disabled = true;

        return;
    }


    screenshots.forEach(
        (src, index) => {

            const img =
                document.createElement("img");


            img.className =
                "screenshot";


            img.src = src;


            img.alt =
                `BLUFFᴮᴰ screenshot ${index + 1}`;


            screenshotTrack.appendChild(img);



            const dot =
                document.createElement("button");


            dot.className =
                `dot ${
                    index === 0
                        ? "active"
                        : ""
                }`;


            dot.setAttribute(
                "aria-label",
                `Go to screenshot ${index + 1}`
            );


            dot.addEventListener(
                "click",
                () => goTo(index)
            );


            dots.appendChild(dot);

        }
    );


    prevButton.disabled = false;

    nextButton.disabled = false;

}



/*
    Move to screenshot.
*/

function goTo(index) {

    if (!screenshots.length) {
        return;
    }


    currentIndex =
        Math.max(
            0,
            Math.min(
                index,
                screenshots.length - 1
            )
        );


    const target =
        screenshotTrack.children[
            currentIndex
        ];


    if (target) {

        target.scrollIntoView({

            behavior: "smooth",

            block: "nearest",

            inline: "start"

        });

    }


    updateDots();
}



/*
    Update carousel dots.
*/

function updateDots() {

    [
        ...dots.children
    ].forEach(
        (dot, index) => {

            dot.classList.toggle(
                "active",
                index === currentIndex
            );

        }
    );

}



/*
    Previous / next buttons.
*/

prevButton.addEventListener(
    "click",
    () => goTo(currentIndex - 1)
);


nextButton.addEventListener(
    "click",
    () => goTo(currentIndex + 1)
);



/*
    Keep dots synced with manual scrolling.
*/

screenshotTrack.addEventListener(
    "scroll",
    () => {

        if (!screenshots.length) {
            return;
        }


        const children =
            [...screenshotTrack.children];


        const left =
            screenshotTrack.scrollLeft;


        let closest = 0;

        let distance = Infinity;


        children.forEach(
            (child, index) => {

                const distanceHere =
                    Math.abs(
                        child.offsetLeft - left
                    );


                if (
                    distanceHere < distance
                ) {

                    distance =
                        distanceHere;

                    closest =
                        index;

                }

            }
        );


        currentIndex =
            closest;


        updateDots();

    },
    {
        passive: true
    }
);



/*
    App icon fallback.

    If icon.png doesn't exist yet,
    the website displays the BLUFFᴮᴰ
    text logo instead.
*/

const appIcon =
    document.getElementById("appIcon");

const iconFallback =
    document.getElementById("iconFallback");

const headerIcon =
    document.getElementById("headerIcon");

const headerIconFallback =
    document.getElementById(
        "headerIconFallback"
    );


appIcon.addEventListener(
    "error",
    () => {

        appIcon.style.display =
            "none";

        iconFallback.style.display =
            "grid";

    }
);


appIcon.addEventListener(
    "load",
    () => {

        iconFallback.style.display =
            "none";

    }
);


headerIcon.addEventListener(
    "error",
    () => {

        headerIcon.style.display =
            "none";

        headerIconFallback.style.display =
            "grid";

    }
);



/*
    About section:
    See more / See less.
*/

const description =
    document.getElementById(
        "description"
    );

const seeMoreButton =
    document.getElementById(
        "seeMoreButton"
    );


seeMoreButton.addEventListener(
    "click",
    () => {

        const expanded =
            description.classList.toggle(
                "expanded"
            );


        description.classList.toggle(
            "collapsed",
            !expanded
        );


        seeMoreButton.textContent =
            expanded
                ? "See less"
                : "See more";

    }
);



/*
    Share button.

    On supported phones/browsers:
    opens the native share menu.

    Otherwise:
    copies the page URL.
*/

async function sharePage() {

    const shareData = {

        title:
            "BLUFFᴮᴰ — Party Games",

        text:
            "Check out BLUFFᴮᴰ, a collection of party games!",

        url:
            window.location.href

    };


    try {

        if (navigator.share) {

            await navigator.share(
                shareData
            );

            return;
        }


        await navigator.clipboard.writeText(
            window.location.href
        );


        alert(
            "Page link copied!"
        );

    } catch (_) {

        // User cancelled sharing.

    }

}


document
    .getElementById("shareButton")
    .addEventListener(
        "click",
        sharePage
    );


document
    .getElementById("heroShareButton")
    .addEventListener(
        "click",
        sharePage
    );



/*
    Start screenshot detection.
*/

findScreenshots().then(
    found => {

        screenshots =
            found;

        renderScreenshots();

    }
);