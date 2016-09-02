{% from "tomcat/map.jinja" import tomcat with context %}

show post map.jinja pillar data:
  test.show_notification:
    - name: show-pillar
    - text: {{tomcat}}