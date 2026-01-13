# MQTT Communicatie Protocol

## Station Implementatie Checklist

### Verbinding Opzetten
- [ ] Verbind met MQTT broker als client met ID: `station-{id}` (bijv. `station-a`)
- [ ] Zorg dat verbinding actief blijft (keep-alive, auto-reconnect)

### Topics om te Abonneren (Commando's Ontvangen)

#### 1. Start Commando
- [ ] Abonneer op: `erd/drugslab/{station-id}/start`
- [ ] Parseer JSON payload:
  ```json
  {
    "team": {"name": "TeamNaam", "score": 1200},
    "time": 210,
    "namesuggestions": ["Naam1", "Naam2", ...]  // Alleen eerste station, wanneer naam "???" is
  }
  ```
- [ ] Start game timer met ontvangen tijd
- [ ] Toon teamnaam en huidige score

#### 2. Server Commando's
- [ ] Abonneer op: `erd/drugslab/{station-id}/server_command`
- [ ] Verwerk `"stop"` commando - stop huidige spel onmiddellijk
- [ ] Verwerk `"restart"` commando - herstart station

#### 3. Team Info (Optioneel)
- [ ] Abonneer op: `erd/drugslab/{station-id}/team` (retained)
- [ ] Ontvang huidige teamgegevens indien nodig

### Topics om te Publiceren (Updates Versturen)

#### 4. Spel Voltooid
- [ ] Publiceer naar: `erd/drugslab/{station-id}/finish`
- [ ] Verstuur wanneer spel eindigt:
  ```json
  {"team": "TeamNaam", "stationscore": 1200}
  ```
- [ ] Gebruik QoS 2, retain: false

#### 5. Tijd Updates
- [ ] Publiceer naar: `erd/drugslab/{station-id}/timeleft`
- [ ] Verstuur aftelling elke seconde: `180` (gewoon getal)
- [ ] Gebruik QoS 0, retain: true
- [ ] Verstuur `0` wanneer spel eindigt of stopt

#### 6. Score Updates
- [ ] Publiceer naar: `erd/drugslab/{station-id}/stationscore`
- [ ] Verstuur huidige score continu: `850` (gewoon getal)
- [ ] Gebruik QoS 0, retain: true
- [ ] Verstuur `0` wanneer spel eindigt of stopt

#### 7. Naam Wijziging (Alleen Eerste Station)
- [ ] Publiceer naar: `erd/drugslab/{station-id}/changename`
- [ ] Verstuur wanneer team nieuwe naam kiest:
  ```json
  {"oldname": "???", "newname": "NieuweTeamNaam"}
  ```
- [ ] Gebruik QoS 2, retain: false
- [ ] Implementeer alleen als dit het eerste station is

### Test Checklist
- [ ] Test verbinding met MQTT broker
- [ ] Test ontvangen van start commando
- [ ] Test publiceren van tijd updates continu
- [ ] Test publiceren van score updates
- [ ] Test publiceren van finish bericht
- [ ] Test stop commando (onderbreekt spel onmiddellijk)
- [ ] Test restart commando
- [ ] Verifieer dat retained berichten worden gewist na einde spel

---

## Referentie: Alle MQTT Topics

### Control Panel → Station
| Topic | QoS | Retained | Payload |
|-------|-----|----------|---------|
| `erd/drugslab/{station-id}/start` | 2 | Nee | `{"team": {"name": "...", "score": 0}, "time": 210}` |
| `erd/drugslab/{station-id}/server_command` | 2 | Nee | `"stop"` of `"restart"` |
| `erd/drugslab/{station-id}/team` | 2 | Ja | `{"name": "...", "scores": {...}}` |

### Station → Control Panel
| Topic | QoS | Retained | Payload |
|-------|-----|----------|---------|
| `erd/drugslab/{station-id}/finish` | 2 | Nee | `{"team": "...", "stationscore": 1200}` |
| `erd/drugslab/{station-id}/timeleft` | 0 | Ja | `180` (getal) |
| `erd/drugslab/{station-id}/stationscore` | 0 | Ja | `850` (getal) |
| `erd/drugslab/{station-id}/changename` | 2 | Nee | `{"oldname": "???", "newname": "..."}` |

### Globale Topics (Alleen Referentie)
- `erd/drugslab/highscores` - Scorebord (retained)
- `erd/drugslab/station-finished/team` - Team voltooiingsstatus (retained)
- `$SYS/brokers/emqx@{hostname}/clients/{client-id}/connected` - Client status
- `$SYS/brokers/emqx@{hostname}/clients/{client-id}/disconnected` - Client status

## Client IDs
- Stations: `station-a`, `station-b`, `station-c`, `station-d`
- Controller: `controller`
- Highscore displays: `highscores-1`
