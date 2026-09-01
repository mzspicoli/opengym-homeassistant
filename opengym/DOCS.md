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
3. You're in. **Continue without account** keeps what you log in this
   browser only, nothing sent anywhere else — that's still there and always
   will be, whether or not you do Step 2.

That's enough for one person browsing locally. Step 2 below is only needed
if more than one person will use it, or if you want accounts that follow you
between devices.

## Step 2 — Real accounts that follow you between devices (optional)

**As of version 0.1.3, this needs no setup for most people.** Real accounts
use passkeys, which are tied to a real web address (like a website has) —
that's a rule of the passkey technology itself, not something this App can
shortcut. But this App now finds that address for you automatically: if
Home Assistant already has a Nabu Casa subscription (Remote UI) or its own
`external_url` configured, sign-in already offers "Create a passkey" with no
Configuration changes at all. Just open openGym and try it.

**If sign-in doesn't offer a passkey option**, Home Assistant has no
external address of its own yet. You have two choices:

- Set one up for Home Assistant itself (Nabu Casa, or your own domain) —
  once that exists, openGym picks it up automatically, and so does anything
  else in Home Assistant that needs it.
- Or give openGym its own separate address, independent of Home Assistant:
  1. Pick a web address you own, for example `gym.yourname.com`. If you
     don't have one, buying a domain name from any registrar and pointing
     it at your home takes a few minutes and usually costs very little.
  2. Follow **Step 3** below to make that address reach openGym, without
     opening any ports on your router.
  3. Come back here, open this App's **Configuration** tab, turn on **Mostrar
     opções de configuração opcionais não utilizadas** (Show unused optional
     configuration options), and fill in:
     - **Passkey hostname**: `gym.yourname.com`
     - **Public URL**: `https://gym.yourname.com`
  4. Restart the App. Open it at that address — sign-in now offers "Create a
     passkey."

Changing the address later (auto-detected or manual) breaks existing
passkeys, so settle on one before people sign up for real.

## Step 3 — Reach it from outside your home (Cloudflare Tunnel)

This makes your web address reach openGym without opening any ports on your
router — free, and Cloudflare handles the security certificate for you.
Pick whichever of the two boxes below matches where you're starting from —
you only need to follow one.

<details>
<summary><strong>I don't have a domain in Cloudflare yet</strong> (click to expand)</summary>

1. Get a domain name from any registrar, if you don't already have one —
   this usually costs very little and takes a few minutes.
2. Create a free account at [cloudflare.com](https://cloudflare.com) if you
   don't have one.
3. In the Cloudflare dashboard, click **Add a domain** and follow the steps
   to add the domain from step 1. Cloudflare will give you two nameservers —
   go to your registrar and point your domain at those nameservers (the
   registrar's site will have a "Nameservers" or "DNS" section for this).
   This can take anywhere from a few minutes to a few hours to take effect.
4. Once Cloudflare shows your domain as **Active**, continue with the "I
   already have a domain in Cloudflare" box below.

</details>

<details>
<summary><strong>I already have a domain added to Cloudflare</strong> (click to expand)</summary>

1. In the Add-on Store, install **Cloudflared** (search for it, it's a
   separate, well-known App — not part of openGym).
2. Follow Cloudflared's own setup to connect it to your Cloudflare account
   and pick your domain.
3. Open Cloudflared's **Configuration** tab and add one entry pointing your
   chosen address at openGym:
   - Hostname: `gym.yourname.com`
   - Service: `http://localhost:8099`
4. Save and restart Cloudflared. Your web address now reaches openGym.

</details>

That's it for most people — the AI connector (Step 4) shares this same
address by default, no second entry needed unless you specifically use an
access-control layer like Cloudflare Access (see Step 4).

## Step 4 — Let an AI assistant read your workouts (optional, advanced)

openGym can let an AI chat app (like Claude or ChatGPT) look up your
workouts when you ask it to, if you turn this on. Skip this section
entirely unless you specifically want that.

- On this App's **Configuration** tab, turn on **Enable AI connector**.
- Leave **AI connector address** blank.
- Restart the App.

**Important if you're relying on Step 2's automatic address** (Nabu Casa or
Home Assistant's own `external_url`, no Configuration changes made): that
kind of address normally requires being logged into Home Assistant to reach
at all, which works fine for you in a browser but not for an AI service
making direct API calls. If the AI connector shows "connected" but tool
calls fail, that's why — give it its own dedicated address instead (Step 3,
then set **AI connector address** to that address).

**Only if** your address from Step 2 sits behind an access-control layer
(Cloudflare Access or a similar login wall in front of the whole domain),
read on — otherwise skip the rest of this section. The AI connector talks
machine-to-machine; it can't complete the kind of interactive login redirect
an access-control layer expects, so it needs its own address that sits
outside that layer entirely:

1. Pick a second web address, different from the one in Step 2 — for
   example `gym-ai.yourname.com`.
2. Set it up the same way as Step 3 (its own Cloudflared entry, pointed at
   port `3001` instead of `8099`) — and make sure this second address is
   **not** covered by your access-control layer's login wall.
3. On this App's **Configuration** tab:
   - Turn on **Enable AI connector**.
   - **AI connector address**: `https://gym-ai.yourname.com`
4. Restart the App.

One more thing, in this access-control case specifically: the login wall in
front of your Step 2 address also needs one narrow exception for the page
`gym.yourname.com/mcp-authorize` — openGym already checks who you are on
that page itself, so the extra login wall there just gets in the way.
Cloudflare Access calls this a "Bypass" rule for that exact address.

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
