{% from "tomcat/map.jinja" import tomcat with context %}
{% set tomcat_java_home = tomcat.java_home %}

include:
  - tomcat
  - tomcat.manager #needed?
  - tomcat.limits

{% for instance_name, instance in tomcat.instances.list.iteritems() %}
{% set tomcat_java_opts = '-' ~ instance.java_opts | join(' -') %}

tomcat service {{ instance.service }}:
  service.running:
    - name: {{ instance.service }}
    - enable: {{ instance.service_enabled }}
    - require:
      - file: limits_conf
    - watch:
      - pkg: tomcat
      - file: limits_conf

tomcat_conf {{ instance_name }}:
  {% if grains.os == 'FreeBSD' %}
  file.append:
    - name: {{ instance.main_config }}
    - text:
      - tomcat{{ instance.ver }}_java_home="{{ instance.java_home }}"
      - tomcat{{ instance.ver }}_java_opts="{{ tomcat_java_opts }}"
  {% else %}
  file.managed:
    - name: {{ instance.main_config }}
    - source: {{ instance.main_config_template }}
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

{% for dir in ['logs','webapps','temp','work','conf'] %}
make {{ instance_name }}/{{ dir }}:
  file.directory:
    - name: {{ tomcat.instances.base }}/{{ instance_name }}/{{ dir }}
    - makedirs: True
    - user: {{instance.user}}
    - group: {{instance.group}}
{% endfor %}

copy default-conf to instance {{ instance_name }}:
  file.recurse:
    - name: {{ tomcat.instances.base }}/{{ instance_name }}/conf
    - source: salt://tomcat/files/default-conf
    - clean: False
    - user: {{ instance.user }}
    - group: {{ instance.group }}
    - file_mode: 644
    - template: jinja
    - defaults:
        instance: {{ instance }}
        instance_name: {{ instance_name }}      
    - require:
      - file: make {{ instance_name }}/conf
    - require_in:
      - service: tomcat service {{ instance.service }}
    - watch_in:
      - service: tomcat service {{ instance.service }}

# 100_server_xml  {{ instance_name }}:
#   file.accumulated:
#     - filename: {{ tomcat.instances.base }}/{{ instance_name }}/conf/server.xml
#     - text: {{ tomcat.connectors }}
#     - require_in:
#       - file: server_xml {{ instance_name }}    

# server_xml {{ instance_name }}:
#   file.managed:
#     - name: {{ tomcat.instances.base }}/{{ instance_name }}/conf/server.xml
#     - source: salt://tomcat/files/server.xml
#     - user: {{ tomcat.user }}
#     - group: {{ tomcat.group }}
#     - mode: '644'
#     - template: jinja
#     - defaults:
#         instance: {{ instance }}
#     - require_in:
#       - service: tomcat service {{ instance.service }}
#     - watch_in:
#       - service: tomcat service {{ instance.service }}      

Link tomcat manager to source for {{ instance_name }}:
  file.symlink:
    - name: {{ tomcat.instances.base }}/{{ instance_name }}/webapps/manager
    - target: /var/lib/tomcat/webapps/manager
    - user: tomcat
    - group: tomcat
    - require:
      - pkg: {{ tomcat.manager_pkg }}

Link tomcat-users.xml to source for {{ instance_name }}:
  file.symlink:
    - name: {{ tomcat.instances.base }}/{{ instance_name }}/conf/tomcat-users.xml
    - target: {{ tomcat.conf_dir }}/tomcat-users.xml
    - user: tomcat
    - group: tomcat
    - force: True
    - require:
      - pkg: {{ instance.pkg }}
      - file: make {{ instance_name }}/conf
    - require_in:
      - service: tomcat service {{ instance.service }}
    - watch_in:
      - service: tomcat service {{ instance.service }}  

{% endfor %}