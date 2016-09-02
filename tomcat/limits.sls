{% from "tomcat/map.jinja" import tomcat with context %}

{% if grains.os != 'FreeBSD' %}
limits_conf:
  {% if grains.os == 'Arch' %}
  file.append:
    - name: /etc/security/limits.conf
    - text:
  {% else %}
  file.managed:
    - name: /etc/security/limits.d/tomcat{{ tomcat.ver }}.conf
    - contents:
  {% endif %}
      - {{ tomcat.user }} soft nofile {{ tomcat.limit_soft }}
      - {{ tomcat.user }} hard nofile {{ tomcat.limit_hard }}
    - require:
      - pkg: tomcat
    - require_in:
      - service: tomcat
    - watch_in:
      - service: tomcat
{% endif %}