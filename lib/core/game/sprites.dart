import 'progression.dart';

/// A horizontal strip of square frames (frames = width / height).
class SpriteSheet {
  const SpriteSheet(this.asset, this.frames);
  final String asset;
  final int frames;
}

class CharacterSprites {
  const CharacterSprites({required this.idle, required this.run, required this.attack});
  final SpriteSheet idle;
  final SpriteSheet run;
  final SpriteSheet attack;
}

const _player = 'ui/characters/player';
const _enemy = 'ui/characters/enemy';

const Map<GameCharacter, CharacterSprites> characterSprites = {
  GameCharacter.pawn: CharacterSprites(
    idle: SpriteSheet('$_player/pawn/Pawn_Idle Axe.png', 8),
    run: SpriteSheet('$_player/pawn/Pawn_Run Axe.png', 6),
    attack: SpriteSheet('$_player/pawn/Pawn_Interact Axe.png', 6),
  ),
  GameCharacter.lancer: CharacterSprites(
    idle: SpriteSheet('$_player/lancer/Lancer_Idle.png', 12),
    run: SpriteSheet('$_player/lancer/Lancer_Run.png', 6),
    attack: SpriteSheet('$_player/lancer/Lancer_Right_Attack.png', 3),
  ),
  GameCharacter.archer: CharacterSprites(
    idle: SpriteSheet('$_player/archer/Archer_Idle.png', 6),
    run: SpriteSheet('$_player/archer/Archer_Run.png', 4),
    attack: SpriteSheet('$_player/archer/Archer_Shoot.png', 8),
  ),
  GameCharacter.monk: CharacterSprites(
    idle: SpriteSheet('$_player/monk/Idle.png', 6),
    run: SpriteSheet('$_player/monk/Run.png', 4),
    attack: SpriteSheet('$_player/monk/Heal.png', 11),
  ),
  GameCharacter.warrior: CharacterSprites(
    idle: SpriteSheet('$_player/warrior/Warrior_Idle.png', 8),
    run: SpriteSheet('$_player/warrior/Warrior_Run.png', 6),
    attack: SpriteSheet('$_player/warrior/Warrior_Attack1.png', 4),
  ),
};

const List<CharacterSprites> enemySprites = [
  CharacterSprites(
    idle: SpriteSheet('$_enemy/torch/torch_idle.png', 7),
    run: SpriteSheet('$_enemy/torch/torch_run.png', 7),
    attack: SpriteSheet('$_enemy/torch/torch_attack.png', 7),
  ),
  CharacterSprites(
    idle: SpriteSheet('$_enemy/tnt/tnt_idle.png', 7),
    run: SpriteSheet('$_enemy/tnt/tnt_run.png', 7),
    attack: SpriteSheet('$_enemy/tnt/tnt_attack.png', 7),
  ),
  CharacterSprites(
    idle: SpriteSheet('$_enemy/barrel/barrel_idle.png', 6),
    run: SpriteSheet('$_enemy/barrel/barrel_run.png', 6),
    attack: SpriteSheet('$_enemy/barrel/barrel_attack.png', 6),
  ),
];

const SpriteSheet deadSprite = SpriteSheet('ui/characters/Dead.png', 7);
