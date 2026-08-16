import {
  effectiveContextReliability,
  type AssistantRequest,
  type AssistantResponse,
} from './contract';
import speciesLabels from '../../../flutter/assets/l10n/zh/species_labels.json';
import { isMegaEvolutionQuestion } from './pokemon_question_scope';

type LabelRecord = Record<string, { en?: string; zh?: string }>;

const megaEvolutionGames = new Set<AssistantRequest['context']['game']>([
  'x',
  'y',
  'omega-ruby',
  'alpha-sapphire',
  'sun',
  'moon',
  'ultra-sun',
  'ultra-moon',
]);

const gameLabels: Record<AssistantRequest['context']['game'], string> = {
  diamond: '宝可梦 钻石',
  pearl: '宝可梦 珍珠',
  platinum: '宝可梦 白金',
  heartgold: '宝可梦 心金',
  soulsilver: '宝可梦 魂银',
  black: '宝可梦 黑',
  white: '宝可梦 白',
  'black-2': '宝可梦 黑2',
  'white-2': '宝可梦 白2',
  x: '宝可梦 X',
  y: '宝可梦 Y',
  'omega-ruby': '宝可梦 欧米伽红宝石',
  'alpha-sapphire': '宝可梦 阿尔法蓝宝石',
  sun: '宝可梦 太阳',
  moon: '宝可梦 月亮',
  'ultra-sun': '宝可梦 究极之日',
  'ultra-moon': '宝可梦 究极之月',
  sword: '宝可梦 剑',
  shield: '宝可梦 盾',
  'brilliant-diamond': '宝可梦 晶灿钻石',
  'shining-pearl': '宝可梦 明亮珍珠',
  'legends-arceus': '宝可梦传说 阿尔宙斯',
  scarlet: '宝可梦 朱',
  violet: '宝可梦 紫',
};

const speciesNames = Object.values(speciesLabels as LabelRecord)
  .flatMap((label) => label.zh?.trim() ? [label.zh.trim()] : [])
  .sort((left, right) => right.length - left.length);

/**
 * Resolve hard version/mechanic incompatibilities before Dex data or a model
 * can reinterpret the wording as an ordinary species evolution question.
 */
export function answerSelectedGameMechanic(
  request: AssistantRequest,
): AssistantResponse | null {
  if (!isMegaEvolutionQuestion(request.question) ||
      megaEvolutionGames.has(request.context.game)) {
    return null;
  }

  const game = gameLabels[request.context.game];
  const species = speciesNames.find((name) => request.question.includes(name));
  const subject = species ?? '所问宝可梦';
  const reliability = effectiveContextReliability(request.context);
  return {
    status: 'answered',
    answer: `《${game}》没有 Mega 进化机制，所以${subject}在这个版本中无法 Mega 进化。你看到的普通进化条件（例如利欧路通过亲密度进化为路卡利欧）不是 Mega 进化条件。`,
    contextUsed: {
      game: request.context.game,
      gameReliability: reliability.game,
      contextReliability: reliability,
    },
    matchedHintIds: [],
    verifiedFacts: [`${game}：Mega 进化不可用`],
    unknowns: [],
    confidence: 'high',
    sources: [],
    followUp: '如果你想问支持 Mega 进化的版本，我可以按具体版本继续查所需道具与获得步骤。',
    onlineComposed: false,
    answerMode: 'local_audited',
  };
}
