/*

	Combat & Stacking Overhaul
	Units
	by Gedemon (2013)


*/


-----------------------------------------------
-- Unit
-----------------------------------------------

/* Range = 1 for all Ranged Land/Sea unit */
UPDATE Units SET Range ='1' WHERE RangedCombat > 0 AND (Domain = 'DOMAIN_LAND' OR Domain = 'DOMAIN_SEA');

/* Range = 0 for Gatling Gun, Machine Gun and Bazooka (purely defensive) */
UPDATE Units SET Range ='0' WHERE Class = 'UNITCLASS_BAZOOKA' OR Class = 'UNITCLASS_GATLINGGUN' OR Class = 'UNITCLASS_MACHINE_GUN';

/* Archer units can't attack ships */
UPDATE Units SET RangeAttackOnlyInDomain ='1' WHERE CombatClass ='UNITCOMBAT_ARCHER';


-----------------------------------------------
-- Unit Promotions
-----------------------------------------------

/* Ocean double move */
INSERT INTO Unit_FreePromotions (UnitType, PromotionType) SELECT Type, 'PROMOTION_SCENARIO_OCEAN_MOVEMENT' FROM Units WHERE Domain ='DOMAIN_SEA';
INSERT INTO UnitPromotions_Terrains (PromotionType, TerrainType, DoubleMove) SELECT Type, 'TERRAIN_OCEAN', 1 FROM UnitPromotions WHERE Type LIKE '%_EMBARKATION';

/* No range promotion for land/sea units */
DELETE FROM UnitPromotions_UnitCombats WHERE (UnitCombatType ='UNITCOMBAT_ARCHER' OR UnitCombatType = 'UNITCOMBAT_NAVALRANGED' OR UnitCombatType = 'UNITCOMBAT_SIEGE') AND PromotionType = 'PROMOTION_RANGE';

/* AA defensive only */
INSERT INTO Unit_FreePromotions (UnitType, PromotionType) VALUES ('UNIT_ANTI_AIRCRAFT_GUN', 'PROMOTION_ONLY_DEFENSIVE');
INSERT INTO Unit_FreePromotions (UnitType, PromotionType) VALUES ('UNIT_MOBILE_SAM', 'PROMOTION_ONLY_DEFENSIVE');


-- to do: sub can move after attack