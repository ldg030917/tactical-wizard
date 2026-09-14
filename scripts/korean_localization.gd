class_name KoreanLocalization
extends RefCounted

const NAMES := {
	"access_key":"황동 열쇠", "ammo_light":"경량탄", "ammo_shell":"산탄", "apprentice_grimoire":"잿빛 마도서", "apprentice_wand":"마가목봉",
	"arcane_dust":"비전분", "ash_essence":"생명 재", "auto_carbine":"갈대선 카빈", "bandage":"깨끗한 붕대", "basic_pistol":"연못가 권총",
	"canteen":"빗물 물통", "cinder_charm":"잿불 수호부", "cloth_armor":"누비 물옷", "cloth":"직조 천", "ember_codex":"잿불실 법전",
	"emberweave_robes":"잿불직 로브", "extended_mag":"넓은부리 탄창", "fire_dagger":"잿불 단검", "grass_dagger":"가시 단검", "water_dagger":"해류 단검", "health_potion":"진홍 회복약",
	"large_pack":"측량꾼 가방", "mana_crystal":"마나 원석", "mana_potion":"마나 물약", "mana_ring":"물결 반지", "med_material":"약초 혼합물",
	"medkit":"현장 치료제", "muzzle_brake":"갈대 제동기", "neutral_dagger":"황금 단검", "novice_hood":"그을음 두건", "parts":"정밀 부품",
	"plate_armor":"선착장 갑옷", "rare_component":"프리즘 코일", "ration":"씨앗 식량", "red_dot":"반딧불 조준기", "rusty_blade":"야영 손도끼",
	"scattergun":"늪지 산탄총", "scrap":"휘어진 고철", "signal_core":"울림 신호핵", "small_pack":"채집꾼 가방", "steady_grip":"코르크 손잡이",
	"transit_token":"수문 통행패", "trinket":"옛 뱃사공 패", "walpurgis_ticket":"발푸르기스 입장권",
	"fireball":"잿불 구체", "ember_dart":"잿불침", "flame_burst":"화염 파열", "cinder_mortar":"잿불 박격탄", "wildfire_orb":"들불 구체",
	"water_bolt":"해일탄", "ice_spear":"서리창", "frost_shard":"빙결 파편", "lightning_arc":"번개 호", "tidal_volley":"해일 연사",
	"thorn_shot":"가시탄", "root_spike":"뿌리 가시", "poison_spore":"독 포자", "seed_barrage":"씨앗 난사", "vine_orb":"덩굴 구체",
	"arcane_bolt":"황금탄", "healing_circle":"초록 안식처", "arcane_missile":"비전탄", "gilt_barrage":"황금 난사", "gravity_orb":"중력 구체",
	"emberstream":"잿불 숨결", "magma_basin":"용암 웅덩이", "searing_wall":"작열 장벽", "smoke_nova":"연막 폭발", "meteor_crown":"유성관",
	"freezing_spray":"빙결 분사", "drowning_puddle":"침수 웅덩이", "ice_wall":"얼음 장벽", "chain_lightning":"연쇄 번개", "water_barrier":"물 장벽",
	"binding_roots":"속박 뿌리", "briar_wall":"가시덤불 벽", "spore_bloom":"포자 개화", "timber_lance":"목재 창", "verdant_mine":"초록 지뢰",
	"blink_sigil":"점멸 인장", "mana_spring":"마나 샘", "aegis_dome":"수호 돔", "cleanse_pulse":"정화 파동", "repulsion_wave":"밀어내기 파동", "explosion":"대폭발",
	"mod_increased_range":"원거리 인장", "mod_curved_trajectory":"곡사 궤도", "mod_ricochet_rune":"도탄 룬", "mod_left_pivot_sigil":"좌회전 인장", "mod_right_pivot_sigil":"우회전 인장",
	"mod_increased_area":"확장 만다라", "mod_projectile_split":"분기 영창", "mod_left_turn":"좌향 궤적", "mod_right_turn":"우향 궤적",
	"mod_ghostglass_rune":"유령유리 룬", "mod_seeker_thread":"추적 실", "mod_prism_beam":"프리즘 광선", "mod_piercing_needle":"관통침", "mod_twin_echo":"쌍둥이 메아리",
	"mod_triple_echo":"삼중 메아리", "mod_volatile_core":"불안정 핵", "mod_frugal_glyph":"절약 문양", "mod_quickcast_knot":"속성전 매듭", "mod_farstep_lens":"먼걸음 렌즈",
	"mod_heavy_comet":"무거운 혜성", "mod_lingering_script":"잔류 각인", "mod_searing_brand":"작열 낙인", "mod_rime_seal":"서리 봉인", "mod_venom_script":"맹독 각인",
	"mod_gravitic_well":"중력 우물", "mod_delayed_echo":"지연 메아리",
	"mana_specialist":"마나 전문가", "scout":"정찰자", "gatherer":"채집가", "healer":"치유사",
	"caldera_archon":"화산분지 집정관", "ash_mage":"재의 맹약 마법사", "cinder_hound":"잿불 사냥개", "melee_creature":"늪지 돌격수", "scavenger":"둑길 약탈자", "strong_guard":"신호 창고 경비병",
	"fire_region":"잿빛 화산분지", "water_region":"침수 기록보관소", "grass_region":"초록 폐허", "neutral_frontier":"황금 천문대",
	"apprentice_recovery":"수습생 복구 세트", "fire_recovery":"기본 불 세트", "water_recovery":"기본 물 세트", "grass_recovery":"기본 풀 세트", "neutral_recovery":"기본 중립 세트",
	"storage":"확장 성물함", "workbench":"룬세공 도구", "medical":"회복 결계", "accuracy":"룬 정밀술", "capacity":"원정 수납술", "casting_speed":"고속 영창", "healing":"회복 수련", "stamina":"긴 호흡", "health":"튼튼한 깃털"
}

const DESCRIPTIONS := {
	"access_key":"봉인된 신호 상자를 엽니다.", "ammo_light":"경량 화기용 탄약 상자입니다.", "ammo_shell":"근거리용 중형 탄약입니다.", "apprentice_grimoire":"기지의 주문 작업실에서 편집하는 3페이지 마도서입니다.", "apprentice_wand":"단순하지만 믿을 만한 마법 촉매입니다.",
	"arcane_dust":"마법 장비 제작을 안정시키는 흔한 잔여물입니다.", "ash_essence":"잿빛 마을의 잿불 야수가 흘린 따뜻한 정수입니다.", "auto_carbine":"늪지 순찰대의 속사 카빈입니다.", "bandage":"출혈을 멎게 하고 체력을 조금 회복합니다.", "basic_pistol":"작고 믿을 만한 보조 화기입니다.",
	"canteen":"깨끗한 빗물이 든 밀봉 물통입니다.", "cinder_charm":"받는 불 피해 일부를 흡수하는 희귀 장신구입니다.", "cloth_armor":"기본적인 다층 현장 방어구입니다.", "cloth":"현장 제작에 쓰는 천입니다.", "ember_codex":"시전이 빠르고 복잡한 주문식을 담는 희귀 마도서입니다.",
	"emberweave_robes":"충격과 화염을 막는 강화 흉부 로브입니다.", "extended_mag":"탄약 8발을 늘리지만 재장전이 조금 느려집니다.", "fire_dagger":"불 원소 단검입니다. 4번 슬롯 선택 후 Space로 공격합니다.", "grass_dagger":"지속 독을 남기는 풀 원소 단검입니다.", "health_potion":"체력을 회복하고 출혈을 멎게 합니다.",
	"large_pack":"원정 가방을 24칸 늘립니다.", "mana_crystal":"물약, 페이지 잉크, 기지 강화에 쓰는 응축 에테르입니다.", "mana_potion":"마나를 즉시 크게 회복합니다.", "mana_ring":"마나 자연 회복 속도를 높이는 장신구입니다.", "med_material":"소독 처리한 늪지 약초입니다.",
	"medkit":"휴대용 응급 치료 세트입니다.", "muzzle_brake":"반동을 줄이고 유효 사거리를 늘립니다.", "neutral_dagger":"원소 상성에 영향받지 않는 중립 단검입니다.", "novice_hood":"내열 안감이 있는 가벼운 머리 방어구입니다.", "parts":"작은 정밀 부품입니다.",
	"plate_armor":"창고 경비병에게 지급되는 중갑입니다.", "rare_component":"온전한 희귀 전자기 부품입니다.", "ration":"짧은 원정용 건조 식량입니다.", "red_dot":"작고 빛나는 조준기입니다.", "rusty_blade":"낡은 다용도 손도끼입니다.",
	"scattergun":"강력한 근거리 산탄총입니다.", "scrap":"간단한 제작에 쓰는 회수 금속입니다.", "signal_core":"봉인 창고에서 회수한 기묘한 송신기입니다.", "small_pack":"원정 가방을 14칸 늘립니다.", "steady_grip":"조준을 안정시키는 단순한 손잡이입니다.", "water_dagger":"얼음과 번개 계열에도 쓰는 물 원소 단검입니다.",
	"transit_token":"자동 나룻배 수문 통행료로 씁니다.", "trinket":"잊힌 항로에서 나온 수집용 패입니다.", "walpurgis_ticket":"금지된 자정 시장의 초대장입니다. 매우 귀중합니다.",
	"mana_specialist":"마나 최대치와 회복이 높으며 장비와 원소 제한이 없습니다.", "scout":"이동과 기력이 뛰어나며 장비 제한 없이 빠르게 위치를 바꿉니다.", "gatherer":"전투 제약 없이 더 빠르게 전리품을 찾고 가방을 넓힙니다.", "healer":"치유와 물약, 중립 보조 능력이 향상되며 장비와 원소 제한이 없습니다.",
	"fire_region":"화상 지대와 불 계열 전리품이 등장합니다. 상위 단계에는 연기, 용암, 폭발 계열이 나옵니다.", "water_region":"침수된 통로가 이동을 늦춥니다. 물 계열은 얼음과 번개로 확장됩니다.", "grass_region":"임시 생명벽이 길을 바꾸되 원정자를 가두지는 않습니다.", "neutral_frontier":"중립 보조 전리품과 드문 타 원소 발견물이 있는 무료 원정지입니다.",
	"storage":"단계마다 영구 보관함을 20칸 늘립니다.", "workbench":"상위 물약과 룬 제작식을 해금합니다.", "medical":"회복과 비전 훈련 시설을 개선합니다.", "accuracy":"단계마다 주문 위력 +7%", "capacity":"단계마다 현장 가방 +2칸", "casting_speed":"단계마다 주문 시전 속도 +5%", "healing":"단계마다 마법과 물약 치유량 +10%", "stamina":"단계마다 기력 +15", "health":"단계마다 최대 체력 +10"
}

const SPELL_DESCRIPTIONS := {
	"fireball":"충돌 시 폭발해 대상을 불태우는 잿불 구체입니다.", "ember_dart":"지속 압박에 좋은 저비용 고속 불꽃침입니다.", "flame_burst":"근거리에서 잿불 세 발을 부채꼴로 발사합니다.", "cinder_mortar":"엄폐물 뒤로 날아가 폭발하는 묵직한 곡사 불 투사체입니다.", "wildfire_orb":"넓은 지역을 막는 느린 불 구체입니다.",
	"water_bolt":"불 원소 대상에게 강한 균형 잡힌 물 투사체입니다.", "ice_spear":"빠르고 정확하며 적중한 적을 둔화시킵니다.", "frost_shard":"대상을 크게 둔화시키는 저비용 얼음 파편입니다.", "lightning_arc":"매우 빠른 물 계열 번개 공격입니다.", "tidal_volley":"넓은 경로에 물 탄환 세 발을 발사합니다.",
	"thorn_shot":"물 원소 대상에게 강한 풀 투사체입니다.", "root_spike":"이동을 크게 늦추는 덩굴 가시입니다.", "poison_spore":"오래가는 독을 남기는 떠다니는 포자입니다.", "seed_barrage":"근거리에서 씨앗 네 발을 빠르게 흩뿌립니다.", "vine_orb":"충돌 시 독 덩굴을 퍼뜨리는 큰 풀 구체입니다.",
	"arcane_bolt":"원소 상성이 없는 안정적인 중립 투사체입니다.", "healing_circle":"범위 안의 시전자를 치유하는 지속 회복진입니다.", "arcane_missile":"사거리와 효율이 좋은 빠른 중립 미사일입니다.", "gilt_barrage":"중립 비전탄 네 발을 부채꼴로 발사합니다.", "gravity_orb":"넓은 충돌 지대를 만드는 느린 곡사 중립 구체입니다.",
	"emberstream":"부채꼴 범위의 적을 태우는 지속 화염입니다.", "magma_basin":"적에게 반복 피해와 화상을 주는 용암 지대를 만듭니다.", "searing_wall":"이동을 막는 임시 화염 장벽을 세웁니다.", "smoke_nova":"뜨거운 연기로 범위 피해와 둔화를 줍니다.", "meteor_crown":"적이 다가오면 폭발하는 유성 인장을 심습니다.",
	"freezing_spray":"부채꼴로 냉기를 뿜어 적을 둔화시킵니다.", "drowning_puddle":"속도를 절반으로 낮추고 받는 물 피해를 늘리는 웅덩이입니다.", "ice_wall":"전장을 가르는 넓은 임시 얼음 장벽입니다.", "chain_lightning":"주변 여러 적을 잇달아 공격하며 위력이 감소합니다.", "water_barrier":"이동을 막는 무거운 물 장벽을 만듭니다.",
	"binding_roots":"범위 안의 적을 땅에서 솟은 뿌리로 묶습니다.", "briar_wall":"전장의 길을 잠시 바꾸는 빽빽한 식물벽입니다.", "spore_bloom":"독 포자 구름을 반복 방출하는 꽃을 피웁니다.", "timber_lance":"일직선의 모든 대상을 관통하는 목재 창입니다.", "verdant_mine":"적이 다가오면 독 덩굴로 터지는 씨앗 지뢰입니다.",
	"blink_sigil":"지정한 안전 지점으로 즉시 공간 이동합니다.", "mana_spring":"안정된 비전 샘을 즉시 마나로 바꿉니다.", "aegis_dome":"피해를 흡수하는 황금 보호막으로 몸을 감쌉니다.", "cleanse_pulse":"출혈, 화상, 중독, 둔화를 없애고 체력을 회복합니다.", "repulsion_wave":"원형 충격파로 적에게 피해를 주고 밀쳐냅니다.", "explosion":"마나가 가득할 때 원정당 한 번 쓰는 최종 불 주문입니다. 시전 후 탈진합니다."
}

const MODIFIER_DESCRIPTIONS := {
	"mod_increased_range":"주문의 유효 사거리를 늘립니다.", "mod_curved_trajectory":"투사체가 낮은 엄폐물 위로 곡사합니다.", "mod_ricochet_rune":"엄폐물에서 튕겨 주변 적을 다시 추적합니다.", "mod_left_pivot_sigil":"지정 지점에서 왼쪽으로 90도 꺾어 진행합니다.", "mod_right_pivot_sigil":"지정 지점에서 오른쪽으로 90도 꺾어 진행합니다.",
	"mod_ghostglass_rune":"주문이 지형 장애물을 통과합니다.", "mod_seeker_thread":"지정 지점 근처의 적을 향해 주문이 잠시 휘어집니다.", "mod_prism_beam":"투사체를 즉발 관통 광선으로 바꿉니다.", "mod_piercing_needle":"적 셋을 관통한 뒤 폭발합니다.", "mod_twin_echo":"투사체를 하나 추가합니다.",
	"mod_triple_echo":"넓은 부채꼴에 투사체 둘을 추가합니다.", "mod_volatile_core":"충돌 범위와 위력을 크게 높입니다.", "mod_frugal_glyph":"위력을 낮추는 대신 마나 소모를 줄입니다.", "mod_quickcast_knot":"주문식을 약화하는 대신 시전 시간을 크게 줄입니다.", "mod_farstep_lens":"지정 사거리와 투사체 속도를 높입니다.",
	"mod_heavy_comet":"주문을 느리고 파괴적인 투사체로 응축합니다.", "mod_lingering_script":"장판, 벽, 보호막, 지뢰의 지속시간을 크게 늘립니다.", "mod_searing_brand":"호환 주문에 화상 후속 효과를 더합니다.", "mod_rime_seal":"냉기 둔화 후속 효과를 더합니다.", "mod_venom_script":"주문식에 지속 독을 더합니다.",
	"mod_gravitic_well":"영향받은 적을 충돌 지점으로 끌어당깁니다.", "mod_delayed_echo":"0.75초 뒤 충돌 효과를 반복합니다.",
	"mod_increased_area":"충돌 폭발과 지속 범위를 넓힙니다.", "mod_projectile_split":"투사체를 위력이 낮은 세 갈래로 나눕니다.", "mod_left_turn":"엄폐물 왼쪽으로 휘어 목표 지점에 접근합니다.", "mod_right_turn":"엄폐물 오른쪽으로 휘어 목표 지점에 접근합니다."
}

const RECIPE_NAMES := {"ammo_bundle":"경량탄 24발 포장", "bandage":"깨끗한 붕대 재봉", "far_reach_sigil":"원거리 인장 새기기", "firefly_sight":"반딧불 조준기 제작", "mana_tonic":"청색 마나 물약 증류", "ration":"씨앗 식량 준비", "ember_codex":"잿불실 법전 제본", "restorative_potion":"진홍 회복약 양조", "surveyor_pack":"측량꾼 가방 제작"}
const RECIPE_DESCRIPTIONS := {"ammo_bundle":"고철과 정밀 부품으로 탄약을 만듭니다.", "bandage":"깨끗한 천과 약초 혼합물을 합칩니다.", "far_reach_sigil":"재사용 양피지에 안정적인 사거리 확장 룬을 새깁니다.", "firefly_sight":"작고 빛나는 조준기를 만듭니다.", "mana_tonic":"수정 에테르를 안정된 현장 물약으로 묶습니다.", "ration":"보급품으로 밀봉 식량 세 개를 준비합니다.", "ember_codex":"페이지 용량이 큰 희귀 내열 마도서를 만듭니다.", "restorative_potion":"생명의 재를 회복용 물약으로 다듬습니다.", "surveyor_pack":"대용량 현장 가방을 만듭니다."}
const QUEST_NAMES := {"ember_sample":"아직 숨 쉬는 재", "cinder_hunt":"잿더미 아래의 이빨", "waygate_return":"재를 가르는 길"}
const QUEST_DESCRIPTIONS := {"ember_sample":"잿빛 마을의 야수에게서 생명 재 하나를 회수하세요.", "cinder_hunt":"잿불 사냥개 셋을 처치하세요.", "waygate_return":"원정에서 살아남아 잿빛 관문으로 귀환하세요."}
const PACKAGE_DESCRIPTIONS := {"apprentice_recovery":"잿빛 마도서, 마가목 불꽃봉, 회복약 두 개와 소형 가방입니다.", "fire_recovery":"교체용 마도서, 불 주문식과 단검, 기본 촉매, 방어구, 회복약입니다.", "water_recovery":"교체용 마도서, 물 주문식과 단검, 기본 촉매, 방어구, 회복약입니다.", "grass_recovery":"교체용 마도서, 풀 주문식과 단검, 기본 촉매, 방어구, 회복약입니다.", "neutral_recovery":"교체용 마도서, 중립 주문식과 단검, 기본 촉매, 방어구, 회복약입니다."}

static func page_name(item_id: String, fallback: String) -> String:
	var spell_id := item_id.trim_suffix("_page")
	return "주문식: %s" % str(NAMES.get(spell_id, fallback.trim_prefix("Formula Page: ")))

static func localize_item(item: ItemData) -> void:
	if item == null: return
	if item.item_id.ends_with("_page"):
		item.display_name = page_name(item.item_id, item.display_name)
		var spell_id := item.item_id.trim_suffix("_page")
		item.description = str(SPELL_DESCRIPTIONS.get(spell_id, item.description))
	else:
		item.display_name = str(NAMES.get(item.item_id, item.display_name))
		item.description = str(DESCRIPTIONS.get(item.item_id, item.description))
	localize_spell(item.base_spell)
	localize_modifier(item.spell_modifier, item.item_id)
	localize_spellbook(item.spellbook)
	localize_focus(item.focus)
	localize_dagger(item.dagger)

static func localize_spell(spell: BaseSpellData) -> void:
	if spell == null: return
	spell.display_name = str(NAMES.get(spell.spell_id, spell.display_name))
	spell.description = str(SPELL_DESCRIPTIONS.get(spell.spell_id, spell.description))

static func localize_modifier(modifier: SpellModifierData, item_id: String = "") -> void:
	if modifier == null: return
	var key := item_id if not item_id.is_empty() else "mod_" + modifier.modifier_id
	modifier.display_name = str(NAMES.get(key, modifier.display_name))
	modifier.description = str(MODIFIER_DESCRIPTIONS.get(key, modifier.description))

static func localize_spellbook(book: SpellbookData) -> void:
	if book == null: return
	book.display_name = str(NAMES.get(book.spellbook_id, book.display_name))
	book.description = str(DESCRIPTIONS.get(book.spellbook_id, book.description))

static func localize_focus(focus: FocusData) -> void:
	if focus == null: return
	focus.display_name = str(NAMES.get(focus.focus_id, focus.display_name))
	focus.description = str(DESCRIPTIONS.get(focus.focus_id, focus.description))

static func localize_dagger(dagger: DaggerData) -> void:
	if dagger == null: return
	dagger.display_name = str(NAMES.get(dagger.dagger_id, dagger.display_name))

static func localize_named(resource: Resource, id_property: String, description_property: String = "description") -> void:
	if resource == null: return
	var id := str(resource.get(id_property))
	resource.set("display_name", str(NAMES.get(id, resource.get("display_name"))))
	resource.set(description_property, str(DESCRIPTIONS.get(id, resource.get(description_property))))

static func localize_recipe(recipe: CraftingRecipeData) -> void:
	if recipe == null: return
	recipe.display_name = str(RECIPE_NAMES.get(recipe.recipe_id, recipe.display_name))
	recipe.description = str(RECIPE_DESCRIPTIONS.get(recipe.recipe_id, recipe.description))

static func localize_quest(quest: QuestData) -> void:
	if quest == null: return
	quest.display_title = str(QUEST_NAMES.get(quest.quest_id, quest.display_title))
	quest.description = str(QUEST_DESCRIPTIONS.get(quest.quest_id, quest.description))

static func localize_package(package: StarterPackageData) -> void:
	if package == null: return
	package.display_name = str(NAMES.get(package.package_id, package.display_name))
	package.description = str(PACKAGE_DESCRIPTIONS.get(package.package_id, package.description))

static func element(id: String) -> String: return {"fire":"불", "water":"물", "grass":"풀", "neutral":"중립", "physical":"물리"}.get(id.to_lower(), id)
static func family(id: String) -> String: return {"fire":"불", "water":"물", "grass":"풀", "neutral":"중립", "ice":"얼음", "lightning":"번개", "magma":"용암", "smoke":"연기", "explosion":"폭발", "cataclysm":"대재앙", "poison":"독", "wood":"나무", "vine":"덩굴", "spore":"포자", "thorn":"가시", "restoration":"회복", "arcane":"비전"}.get(id.to_lower(), id.replace("_", " "))
static func status(id: String) -> String: return {"":"없음", "burn":"화상", "slow":"둔화", "poison":"중독", "bleeding":"출혈", "water_vulnerable":"침수"}.get(id.to_lower(), id.replace("_", " "))
static func category(id: String) -> String: return {"spell":"주문식", "spellbook":"마도서", "focus":"촉매", "dagger":"단검", "head":"머리", "chest":"몸통", "accessory_1":"장신구 1", "accessory_2":"장신구 2", "backpack":"가방", "consumable_1":"퀵슬롯 1", "consumable_2":"퀵슬롯 2", "spell_modifier":"부착 룬", "melee":"근접 무기", "armor_head":"머리 방어구", "armor_chest":"흉부 방어구", "armor":"방어구", "accessory":"장신구", "medical":"회복품", "mana_consumable":"마나 회복품", "food":"식량", "drink":"음료", "crafting":"제작 재료", "quest":"의뢰품", "key":"열쇠", "valuable":"귀중품", "ammo":"탄약", "weapon":"무기", "attachment":"부착물"}.get(id, id.replace("_", " "))
static func trajectory(id: String) -> String: return {"straight":"직선", "left_turn":"좌회전", "right_turn":"우회전", "high_lob":"곡사", "unchanged":"기본"}.get(id, id.replace("_", " "))
static func behavior(id: String) -> String: return {"projectile":"투사체", "cone":"부채꼴", "damage_zone":"피해 지대", "slow_zone":"둔화 지대", "root_field":"속박 지대", "puddle":"웅덩이", "wall":"장벽", "barrier":"보호막", "mine":"지뢰", "chain":"연쇄", "beam":"광선", "teleport":"점멸", "mana_restore":"마나 회복", "cleanse":"정화", "shield":"보호막", "knockback":"밀쳐내기"}.get(id, id.replace("_", " "))
