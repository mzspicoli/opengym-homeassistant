# openGym

A gym and body-weight tracker you run yourself — your workouts stay on your
own Home Assistant, not on someone else's server.

**This is a repackaging, not the original project.** openGym itself was
built by Duarte Santos and its contributors at
[gitlab.com/DuarteSantos8/opengym](https://gitlab.com/DuarteSantos8/opengym)
— that's the real project. This App only adds what's needed to run it inside
Home Assistant; nothing about openGym itself was changed.

## Step 1 — Just try it (no setup needed)

1. Click **Start**.
2. Open openGym from the Home Assistant sidebar.
3. You're in, in **Guest mode** — everything you log stays only in this
   browser, nothing is sent anywhere else.

That's enough to try it out, or for one person browsing locally. Everything
below is only needed if more than one person will use it, or if you want to
open it from outside the house.

## Step 2 — Give people real accounts (optional)

Guest mode keeps data in one browser only. For real accounts that follow you
between devices, openGym needs a proper web address (like a website has) —
this is a rule of the passkey login technology itself, not something this
App can shortcut.

1. Pick a web address you own, for example `gym.yourname.com`. If you don't
   have one, buying a domain name from any registrar and pointing it at your
   home takes a few minutes and usually costs very little.
2. Follow **Step 3** below to make that address reach your Home Assistant,
   without opening any ports on your router.
3. Come back here, open this App's **Configuration** tab, and fill in:
   - **Passkey hostname**: `gym.yourname.com`
   - **Public URL**: `https://gym.yourname.com`
4. Restart the App. Open it at that address — sign-in now offers "Create a
   passkey."

Changing the hostname later breaks existing passkeys, so pick it before
people sign up for real.

## Step 3 — Reach it from outside your home (Cloudflare Tunnel)

This makes your web address reach openGym without opening any ports on your
router — free, and Cloudflare handles the security certificate for you.

1. In the Add-on Store, install **Cloudflared** (search for it, it's a
   separate, well-known App — not part of openGym).
2. Follow Cloudflared's own setup to connect it to a free Cloudflare
   account and pick your domain.
3. Open Cloudflared's **Configuration** tab and add one entry pointing your
   chosen address at openGym:
   - Hostname: `gym.yourname.com`
   - Service: `http://localhost:8099`
4. Save and restart Cloudflared. Your web address now reaches openGym.

**Using the AI connector (Step 4) too?** Add a second entry the same way,
with your second hostname (see Step 4) pointing at `http://localhost:3001`
instead.

## Step 4 — Let an AI assistant read your workouts (optional, advanced)

openGym can let an AI chat app (like Claude or ChatGPT) look up your
workouts when you ask it to, if you turn this on. Skip this section
entirely unless you specifically want that.

This needs its **own second web address**, different from the one in Step 2
— for example `gym-ai.yourname.com`. Set it up the same way as Step 3 (its
own Cloudflared entry, pointed at port `3001` instead of `8099`), then on
this App's **Configuration** tab:

- Turn on **Enable AI connector**
- **AI connector address**: `https://gym-ai.yourname.com`

One more thing, only if your main address (from Step 2) sits behind a login
wall like Cloudflare Access: that login wall needs one narrow exception for
the page `gym.yourname.com/mcp-authorize` specifically — openGym already
checks who you are on that page itself, so the extra login wall there just
gets in the way. Cloudflare Access calls this a "Bypass" rule for that exact
address. If you don't use a login wall like that, there's nothing extra to
do here.

## Optional: make yourself an administrator

Most people never need this — skip it unless you specifically want an admin
dashboard (to manage multiple people, require invite codes, etc.).

Being an admin isn't something you turn on from inside openGym itself; it's
set here, on this App's **Configuration** tab, in the **Admin user IDs**
field. To find your own ID, sign up for your openGym profile first, then
look inside this App's data storage for a file named `db.json` and copy the
`id` listed next to your name — the **Terminal & SSH** App (from the Store)
is the most reliable way to browse there if you don't already have another
way to open files on this App's storage. Paste that ID into the field above
and restart the App.

## Your data

Everything you log — profiles, passkeys, workouts, downloaded exercise
pictures, and AI-connector settings if you turned that on — lives in this
App's own storage, which Home Assistant backs up automatically as part of a
normal Supervisor backup. There's nothing extra to configure for that.
