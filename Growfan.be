#######################################################################
# GrowFan Automatic Speed Control 
#######################################################################

import persist
import webserver
import json
import mqtt

var GrowFan_ui = module('GrowFan_ui')
  
class GrowFan_UI

  # wird beim starten einmalig aufgerufen
  def init()
    #standartwerte festlegen falls keine vorhanden
    tasmota.cmd("PWMFrequency 20000")
    tasmota.cmd("PWMRange 255")
    tasmota.cmd("LedTable 0")

    print("GrowFan init")
     if ! persist.has("TMIN")
       persist.TMIN=23
     end
     if ! persist.has("TMAX")
       persist.TMAX=30
     end
     if ! persist.has("HMIN")
       persist.HMIN=45
     end
     if ! persist.has("HMAX")
       persist.HMAX=65
     end
     if ! persist.has("VMIN")
      persist.VMIN=37
     end
     if ! persist.has("VMAX")
      persist.VMAX=100
     end
     if ! persist.has("cTime")
      persist.cTime=1
     end
     if ! persist.has("PumpEnable")
       persist.PumpEnable=True
     end
     persist.save()
     tasmota.remove_cron("change_cron")
     #tasmota.add_cron(format("* */%d * * * *",persist.cTime), def () self.changeFanSpeed() end, "change_cron")
     #tasmota.add_cron("* */1 * * * *", self.changeFanSpeed, "change_cron")
     self.set_timer_modulo(persist.cTime*60*1000,def () self.changeFanSpeed() end,"change_timer")
     self.subscribes()
    
  end

  def MQTT_receive_persists(topic, idx, payload_s, payload_b)
    print("topic: ", topic)
    print(">>>", payload_s)
    if topic == "homeassistant/sensor/growfan/set/TMAX"
      persist.TMAX = int(payload_s)
    end
    if topic == "homeassistant/sensor/growfan/set/TMIN"
      persist.TMIN = int(payload_s)
    end
    if topic == "homeassistant/sensor/growfan/set/HMAX"
      persist.HMAX = int(payload_s)
    end
    if topic == "homeassistant/sensor/growfan/set/HMIN"
      persist.HMIN = int(payload_s)
    end
    if topic == "homeassistant/sensor/growfan/set/VMAX"
      persist.VMAX= int(payload_s)
    end
    if topic == "homeassistant/sensor/growfan/set/VMIN"
      persist.VMIN = int(payload_s)
    end
    if topic == "homeassistant/sensor/growfan/set/cTime"
      persist.cTime = int(payload_s)
      self.update_timer(int(payload_s))
    end
    if topic == "homeassistant/sensor/growfan/set/autoControl"
      var state = true
      if payload_s == "True"
        state = true
      end
      if payload_s == "False"
        state = false
      end
      persist.PumpEnable = state
    end

    persist.save()
    self.MQTT_send_persists()
    return true
  end
  
  
  
  def subscribes()
    mqtt.subscribe("homeassistant/sensor/growfan/set/TMIN", def(topic, idx, payload_s, payload_b) self.MQTT_receive_persists(topic, idx, payload_s, payload_b) end)
    mqtt.subscribe("homeassistant/sensor/growfan/set/TMAX", def(topic, idx, payload_s, payload_b) self.MQTT_receive_persists(topic, idx, payload_s, payload_b) end)
    mqtt.subscribe("homeassistant/sensor/growfan/set/HMAX", def(topic, idx, payload_s, payload_b) self.MQTT_receive_persists(topic, idx, payload_s, payload_b) end)
    mqtt.subscribe("homeassistant/sensor/growfan/set/HMIN", def(topic, idx, payload_s, payload_b) self.MQTT_receive_persists(topic, idx, payload_s, payload_b) end)
    mqtt.subscribe("homeassistant/sensor/growfan/set/VMAX", def(topic, idx, payload_s, payload_b) self.MQTT_receive_persists(topic, idx, payload_s, payload_b) end)
    mqtt.subscribe("homeassistant/sensor/growfan/set/VMIN", def(topic, idx, payload_s, payload_b) self.MQTT_receive_persists(topic, idx, payload_s, payload_b) end)
    mqtt.subscribe("homeassistant/sensor/growfan/set/cTime", def(topic, idx, payload_s, payload_b) self.MQTT_receive_persists(topic, idx, payload_s, payload_b) end)
    mqtt.subscribe("homeassistant/sensor/growfan/set/autoControl", def(topic, idx, payload_s, payload_b) self.MQTT_receive_persists(topic, idx, payload_s, payload_b) end)
  end
  
  def MQTT_send_persists()
    var values = format('{"TMIN": %d, "TMAX": %d, "HMIN": %d, "HMAX": %d, "VMIN": %d, "VMAX": %d, "cTime": %d, "autoControl": %s}', persist.TMIN, persist.TMAX, persist.HMIN, persist.HMAX, persist.VMIN, persist.VMAX,persist.cTime, persist.PumpEnable ? "true" : "false")
    mqtt.publish("homeassistant/sensor/growfan/config", values)
    return true
  end
  

  def changeFanSpeed()
    if persist.PumpEnable
      var tempSpeed = self.calculate_fan_speed_temp()
      var humSpeed = self.calculate_fan_speed_hum()
      print(format("TempSpeed: %d HumSpeed: %d",tempSpeed,humSpeed))
      if tempSpeed > humSpeed
        self.setFanSpeed(tempSpeed)
        print(format("changeFanSpeed(%d) aufgerufen (temp)",tempSpeed))
      else
        self.setFanSpeed(humSpeed)
        print(format("changeFanSpeed(%d) aufgerufen (hum)",humSpeed))
      end
    else
      print("Automatische Steuerung deaktiviert")
    end
  end



  def calculate_fan_speed_temp()
    #berechnen der geschwindigkeit anhand der Temperatur
    var current_temp = self.get_temperature()
    var temp_range = persist.TMAX - persist.TMIN
    var temp_slope = (persist.VMAX - persist.VMIN) / temp_range
    var temp_fan_speed = temp_slope * (current_temp - persist.TMIN) + persist.VMIN

    if temp_fan_speed <= persist.VMIN
      temp_fan_speed = persist.VMIN
    end
    if temp_fan_speed >= persist.VMAX
      temp_fan_speed = persist.VMAX
    end

    return int(temp_fan_speed)
  end
  
  def calculate_fan_speed_hum()
    #berechnen der geschwindigkeit anhand der Feuchtigkeit
    var current_hum = self.get_humidity()
    var temp_range = persist.HMAX - persist.HMIN
    var temp_slope = (persist.VMAX - persist.VMIN) / temp_range
    var temp_fan_speed = temp_slope * (current_hum - persist.HMIN) + persist.HMIN

    if temp_fan_speed <= persist.VMIN
      temp_fan_speed = persist.VMIN
    end
    if temp_fan_speed >= persist.VMAX
      temp_fan_speed = persist.VMAX
    end

    return int(temp_fan_speed)
  end

  def mqtt_updater()

  end

  def setFanSpeed(speed)
  # Geschwindigkeit des Lüfters festlegen
    # Begrenze den Wert zwischen 0 und 100
    if speed < 0
      speed = 0
    end
    if speed > 100
      speed = 100
    end

    # Sende den Befehl an Tasmota, um den Lüfter auf den gewünschten Wert zu setzen
    tasmota.cmd(format("Dimmer %d", speed))
  end

  def get_temperature()
  #ermittelt die aktuelle temperatur
    var sensors = json.load(tasmota.read_sensors())
    return sensors['SHT3X']['Temperature']
  end

  def get_humidity()
    #ermittelt die aktuelle temperatur
      var sensors = json.load(tasmota.read_sensors())
      return sensors['SHT3X']['Humidity']
  end

  def set_timer_modulo(delay,f,id)
    var now=tasmota.millis()
    tasmota.set_timer((now+delay/4+delay)/delay*delay-now, def() self.set_timer_modulo(delay,f,id) f() end, id)
  end

  def update_timer(delay)
    var tem_delay=delay*60*1000
    tasmota.remove_timer("change_timer")
    self.set_timer_modulo(tem_delay,def () self.changeFanSpeed() end,"change_timer")
  end

  
  def changeCronTime(ctime)
    tasmota.remove_cron("change_cron")
    tasmota.add_cron(format("* */%d * * * *",persist.cTime), def () self.changeFanSpeed() end, "change_cron")
  end

  #wird beim generieren der Menübuttons aufgerufen
  def web_add_main_button()
    webserver.content_send("<p><form id=GrowFan_ui action='GrowFan_ui' style='display: block;' method='get'><button>GrowFan Config</button></form></p>")
   
  end   
  
  
  #######################################################################
  # Display the complete page on `/GrowFan_ui'
  #######################################################################
  
  def page_GrowFan_ui()
    # Generiert das Config Menü
    if !webserver.check_privileged_access() return nil end
  
      webserver.content_start("GrowFan")           #- title of the web page -#
      webserver.content_send_style()                  #- send standard Tasmota styles -#
      webserver.content_send("<fieldset><style>.bdis{background:#888;}.bdis:hover{background:#888;}</style>")
      webserver.content_send(format("<legend><b title='GrowFan'>GrowFan Konfiguration</b></legend>"))
      webserver.content_send("<p><form id=GrowFan_ui style='display: block;' action='/GrowFan_ui' method='post'>")
      webserver.content_send(format("<table style='width:100%%'>"))
      webserver.content_send("<tr><td style='width:300px'><b>Automatische Steuerung</b></td>")
      webserver.content_send(format("<td style='width:100px'><input type='checkbox' name='PumpEnable'%s></td></tr>", persist.PumpEnable ? " checked" : ""))
      webserver.content_send("<tr><td style='width:300px'><b>minimale Temperatur</b></td>")
      webserver.content_send(format("<td style='width:100px'><input type='number' min='1' max='100' name='TMIN' value='%i'></td></tr>", persist.TMIN))
      webserver.content_send("<tr><td style='width:300px'><b>maximale Temperatur</b></td>")
      webserver.content_send(format("<td style='width:100px'><input type='number' min='1' max='100' name='TMAX' value='%i'></td></tr>", persist.TMAX))
      webserver.content_send("<tr><td style='width:300px'><b>minimale Luftfeuchtigkeit</b></td>")
      webserver.content_send(format("<td style='width:100px'><input type='number' min='1' max='100' name='HMIN' value='%i'></td></tr>", persist.HMIN))
      webserver.content_send("<tr><td style='width:300px'><b>maximale Luftfeuchtigkeit</b></td>")
      webserver.content_send(format("<td style='width:100px'><input type='number' min='1' max='100' name='HMAX' value='%i'></td></tr>", persist.HMAX))
      webserver.content_send("<tr><td style='width:300px'><b>minimale Lüftergeschwindigkeit</b></td>")
      webserver.content_send(format("<td style='width:100px'><input type='number' min='1' max='100' name='VMIN' value='%i'></td></tr>", persist.VMIN))
      webserver.content_send("<tr><td style='width:300px'><b>maximale Lüftergeschwindigkeit</b></td>")
      webserver.content_send(format("<td style='width:100px'><input type='number' min='1' max='100' name='VMAX' value='%i'></td></tr>", persist.VMAX))
      webserver.content_send("<tr><td style='width:300px'><b>Anpassungsintervall (min)</b></td>")
      webserver.content_send(format("<td style='width:100px'><input type='number' min='1' max='100' name='cTime' value='%i'></td></tr>", persist.cTime))
      webserver.content_send("</table><hr>")
      webserver.content_send("<button name='GrowFanApply' class='button bgrn'>SET</button>")
      webserver.content_send("</form></p>")
      webserver.content_send("<p></p></fieldset><p></p>")
      webserver.content_button(webserver.BUTTON_CONFIGURATION)
      webserver.content_stop()

    end
    
    def page_GrowFan_ctl()
    #logik des SET Buttons, speichert die werte im Menü
      if !webserver.check_privileged_access() return nil end
      import introspect
      
      try
        if webserver.has_arg("GrowFanApply")
          print("SET Button gedrückt")
          # read arguments
          persist.TMIN = int(webserver.arg("TMIN"))
          persist.TMAX = int(webserver.arg("TMAX"))
          persist.HMIN = int(webserver.arg("HMIN"))
          persist.HMAX = int(webserver.arg("HMAX"))
          persist.VMIN = int(webserver.arg("VMIN"))
          persist.VMAX = int(webserver.arg("VMAX"))
          persist.cTime = int(webserver.arg("cTime"))
          persist.PumpEnable = webserver.arg("PumpEnable") == 'on'
          persist.save()
          #self.changeCronTime(persist.cTime)
          self.update_timer(persist.cTime)
          self.MQTT_send_persists()

          webserver.redirect("/")
        end
      except .. as e,m
        print(format("BRY: Exception> '%s' - %s", e, m))
        #- display error page -#
        webserver.content_start("Parameter error")           #- title of the web page -#
        webserver.content_send_style()                  #- send standard Tasmota styles -#

        webserver.content_send(format("<p style='width:340px;'><b>Exception:</b><br>'%s'<br>%s</p>", e, m))

        webserver.content_button(webserver.BUTTON_CONFIGURATION) #- button back to management page -#
        webserver.content_stop()                        #- end of web page -#
      end
    end
    
    
    #- ---------------------------------------------------------------------- -#
    # respond to web_add_handler() event to register web listeners
    #- ---------------------------------------------------------------------- -#
    #- this is called at Tasmota start-up, as soon as Wifi/Eth is up and web server running -#
      
    def web_add_handler()
      #- we need to register a closure, not just a function, that captures the current instance -#
      webserver.on("/GrowFan_ui", / -> self.page_GrowFan_ui(), webserver.HTTP_GET)
      webserver.on("/GrowFan_ui", / -> self.page_GrowFan_ctl(), webserver.HTTP_POST)
    end
end  

GrowFan_ui.GrowFan_UI=GrowFan_UI


#- create and register driver in Tasmota -#
#if tasmota
  var GrowFan_ui_instance = GrowFan_ui.GrowFan_UI()
  tasmota.add_driver(GrowFan_ui_instance)
  ## can be removed if put in 'autoexec.bat'
  GrowFan_ui_instance.web_add_handler()
  
#end

return GrowFan_ui