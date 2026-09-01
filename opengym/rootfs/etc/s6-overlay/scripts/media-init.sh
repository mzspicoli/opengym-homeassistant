#!/usr/bin/with-contenv bashio
# Downloads the exercise img/gif dataset into persistent /data once, then makes it
# visible to nginx at the paths openGym's own regex location block already expects
# (it just needs the files to exist under the html root, same as the original
# docker-compose bind mount achieved). See docker-compose.yml's `media` service
# upstream for the source of this logic — kept in sync by hand, not scripted.
set -e

mkdir -p /data/media/img /data/media/gif
ln -sfn /data/media/img /usr/share/nginx/html/img
ln -sfn /data/media/gif /usr/share/nginx/html/gif

if [ -z "$(ls -A /data/media/img 2>/dev/null)" ]; then
    bashio::log.info "Downloading exercise media (~140 MB, one time)…"
    rm -rf /tmp/exercises-dataset
    git clone --depth 1 https://github.com/hasaneyldrm/exercises-dataset /tmp/exercises-dataset
    cp /tmp/exercises-dataset/images/*.jpg /data/media/img/
    cp /tmp/exercises-dataset/videos/*.gif /data/media/gif/
    rm -rf /tmp/exercises-dataset
    bashio::log.info "Exercise media ready."
else
    bashio::log.info "Exercise media already present — skipping download."
fi
