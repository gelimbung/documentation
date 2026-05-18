FROM odoo:18

USER root

# Install pip + dependencies OpenUpgrade
RUN apt-get update \
 && apt-get install -y --no-install-recommends python3-pip \
 && python3 -m pip install --no-cache-dir --break-system-packages \
    qifparse \
    openupgradelib \
 && apt-get purge -y python3-pip \
 && apt-get autoremove -y \
 && rm -rf /var/lib/apt/lists/*

USER odoo
