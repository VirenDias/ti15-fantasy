import sys
import vdf
import re

with open(sys.argv[1]) as file:
    data = vdf.load(file)['DOTAHeroes']

# Extract the base data
base_adjs = data.pop('npc_dota_hero_base')['Adjectives']
base_adjs['Universal'] = 0
base_adjs['Strength'] = 0
base_adjs['Intelligence'] = 0
base_adjs['Agility'] = 0

for hero in data.values():
    if isinstance(hero, dict):
        for adj in hero.get('Adjectives', {}):
            if adj not in base_adjs:
                base_adjs[adj] = 0

base_adjs = {key: base_adjs[key] for key in sorted(base_adjs)}
base_hero = {'HeroId': 0, 'HeroName': 'npc_dota_hero_base'}
base_hero.update(base_adjs)

regex = re.compile(r'(?<!^)(?=[A-Z])')
print(','.join([regex.sub('_', key).lower() for key in base_hero.keys()]))

# Extract the hero data
for key in data:
    if 'Adjectives' in data[key]:
        hero = base_hero.copy()
        
        hero.update(data[key]['Adjectives'])
        if data[key]['AttributePrimary'] == 'DOTA_ATTRIBUTE_STRENGTH':
            hero['Strength'] = 1
        if data[key]['AttributePrimary'] == 'DOTA_ATTRIBUTE_AGILITY':
            hero['Agility'] = 1
        if data[key]['AttributePrimary'] == 'DOTA_ATTRIBUTE_INTELLECT':
            hero['Intelligence'] = 1
        if data[key]['AttributePrimary'] == 'DOTA_ATTRIBUTE_ALL':
            hero['Universal'] = 1
        hero.update({'HeroId': data[key]['HeroID'], 'HeroName': key})
        
        print(','.join([str(value) for value in hero.values()]))
