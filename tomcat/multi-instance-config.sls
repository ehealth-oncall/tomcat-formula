{% from "tomcat/map.jinja" import tomcat with context %}
{% set tomcat_java_home = tomcat.java_home %}

include:
  - tomcat

{% for instance_name, instance in tomcat.instances.iteritems() %}
{% set tomcat_java_opts = '-' ~ instance.java_opts | join(' -') %}

tomcat service {{ instance.service }}:
  service.running:
    - name: {{ instance.service }}
    - enable: {{ instance.service_enabled }}
    - watch:
      - pkg: tomcat
# To install haveged in centos you need the EPEL repository
{% if tomcat.with_haveged %}
  require:
    - pkg: haveged
{% endif %}

tomcat_conf {{ instance_name }}:
  {% if grains.os == 'FreeBSD' %}
  file.append:
    - name: {{ tomcat.main_config }}
    - text:
      - tomcat{{ tomcat.ver }}_java_home="{{ tomcat_java_home }}"
      - tomcat{{ tomcat.ver }}_java_opts="{{ tomcat_java_opts }}"
  {% else %}
  file.managed:
    - name: {{ instance.main_config }}
    - source: {{ tomcat.main_config_template }}
    - template: jinja
    - defaults:
        tomcat: {{ instance }}
  {% endif %}
    - require:
      - pkg: tomcat
    - require_in:
      - service: tomcat service {{ instance.service }}
    - watch_in:
      - service: tomcat service {{ instance.service }}

{% for dir in  ['logs','webapps','temp','work','conf'] %}
make {{ instance_name }}/{{ dir }}:
  file.directory:
    - name: {{ tomcat.instances_base }}/{{ instance_name }}/{{ dir }}
    - makedirs: True
    - user: tomcat
    - group: tomcat
{% endfor %}

copy default-conf to instance {{ instance_name }}:
  file.recurse:
    - name: {{ tomcat.instances_base }}/{{ instance_name }}/conf
    - source: salt://tomcat/files/default-conf
    - clean: False
    - user: tomcat
    - group: tomcat
    - file_mode: 664
    - require:
      - file: make {{ instance_name }}/conf
    - require_in:
      - service: tomcat service {{ instance.service }}
    - watch_in:
      - service: tomcat service {{ instance.service }}

100_server_xml  {{ instance_name }}:
  file.accumulated:
    - filename: {{ tomcat.instances_base }}/{{ instance_name }}/conf/server.xml
    - text: {{ tomcat.connectors }}
    - require_in:
      - file: server_xml {{ instance_name }}    

server_xml  {{ instance_name }}:
  file.managed:
    - name: {{ tomcat.instances_base }}/{{ instance_name }}/conf/server.xml
    - source: salt://tomcat/files/server.xml
    - user: {{ tomcat.user }}
    - group: {{ tomcat.group }}
    - mode: '644'
    - template: jinja
    - require_in:
      - service: tomcat service {{ instance.service }}
    - watch_in:
      - service: tomcat service {{ instance.service }}      

Link tomcat manager to source:
  file.symlink:
    - name: {{ tomcat.instances_base }}/{{ instance_name }}/webapps/manager
    - target: /var/lib/tomcat/webapps/manager
    - user: tomcat
    - group: tomcat
    - require:
      - pkg: {{ tomcat.manager_pkg }}

Link tomcat-users.xml to source:
  file.symlink:
    - name: {{ tomcat.c_base }}/conf/tomcat-users.xml
    - target: {{ tomcat.conf_dir }}/tomcat-users.xml
    - user: tomcat
    - group: tomcat
    - force: True
    - require:
      - pkg: {{ tomcat.pkg }}
      - file: make {{ instance_name }}/conf
    - require_in:
      - service: tomcat service {{ instance.service }}
    - watch_in:
      - service: tomcat service {{ instance.service }}  

{% endfor %}

  

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