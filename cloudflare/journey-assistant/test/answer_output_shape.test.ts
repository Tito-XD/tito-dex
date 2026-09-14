import { describe, expect, it } from 'vitest';
import { generatedAnswerGuardFailure } from '../src/answer_quality_guards';

describe('final generated answer shape', () => {
  it.each([
    "{  'supported': true,  'points': [ '基础能量卡没有属性。",
    '{"answer":"武藏是火箭队成员。","supported":true}',
    '```json\n{"claims":[{"text":"宝可梦资料"}]}\n```',
  ])('rejects an inner model object even when it was delivered as a string', (answer) => {
    expect(generatedAnswerGuardFailure({ answer, question: '介绍宝可梦资料' })).toBe('model_output_envelope');
  });
  it.each(['悖谬宝可梦是一个类别。例如：', 'These are Pokémon. For example:'])('rejects empty example promises', (answer) => {
    expect(generatedAnswerGuardFailure({ answer, question: '举几个例子' })).toBe('incomplete_answer');
  });
  it('retains plain prose and actual examples', () => {
    expect(generatedAnswerGuardFailure({ answer: '宝可梦有多种属性，例如：皮卡丘是电属性。', question: '举个例子' })).toBeNull();
  });
});
