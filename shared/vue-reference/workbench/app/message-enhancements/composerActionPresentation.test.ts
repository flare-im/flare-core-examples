import { describe, expect, it } from "vitest";
import { composerActions } from "./messageTypeRegistry";
import { createComposerAttachActions } from "./composerActionPresentation";

describe("composer action presentation", () => {
  it("exposes voice recording and every non-duplicate SDK message builder", () => {
    const actions = createComposerAttachActions(composerActions, (key) => `translated:${key}`);
    const ids = actions.map((action) => action.id);
    const intents = actions.map((action) => action.intent);

    expect(ids[0]).toBe("voice");
    expect(actions[0].label).toBe("translated:composer.voice");
    expect(actions.find((action) => action.id === "file")?.label).toBe("translated:composeType.file.label");
    expect(new Set(ids).size).toBe(ids.length);
    expect(intents).toContain("create_image");
    expect(intents).toContain("create_file");
    expect(intents).toContain("create_video");
    expect(intents).toContain("create_rich_doc");
    expect(intents).toContain("create_vote");
    expect(intents).toContain("create_announcement");
    expect(intents.filter((intent) => intent === "voice")).toHaveLength(1);
    expect(intents).not.toContain("create_audio");
  });
});
