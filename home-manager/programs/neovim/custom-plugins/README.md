## Plugin Overview

This plugin enhances your coding experience by integrating with OpenAI's GPT
model, allowing you to interactively modify and replace code snippets within
your text editor. When you select a portion of text in visual mode and trigger
the command, a popup appears displaying the selected text, with an additional
input prompt for you to provide instructions or modifications you'd like to
make to the code.

### Usage Steps

1. **Select Text**: First, highlight the portion of code you want to modify by
   entering visual mode (`v` in normal mode), then move your cursor to select
   the desired text.

2. **Trigger the Plugin**: Once your text is selected, press `<leader>p`
   (where `<leader>` represents your configured leader key, commonly `\`).

3. **Visualize Your Selection**: A popup titled "Selected Text" will display
   the highlighted code. You can review this and decide if you wish to modify
   it.

4. **Input Custom Prompt**: Below the selected text, an input popup will
   appear, prompting you to specify your request, such as "Refactor this code
   for better readability" or "Explain how this function works." You’ll see a
   clear visualization of the selected text as you type your instructions.

5. **Submit Your Request**: Press `<leader>s` to send your prompt along with
   the selected text to the OpenAI API. You’ll receive feedback indicating
   whether the request was successfully sent or if there was an error.

6. **Review the Response**: The result will be displayed in a separate popup
   titled "Response." You can inspect the modifications or explanations
   provided by the model.

7. **Replace Original Text (Optional)**: If you're happy with the response,
   you can easily save the changes back to your original buffer by pressing
   `<leader>s` again within the response popup.

### Example

For instance, if you select a function in your code and input "Can you improve
the performance of this function?" in the prompt, the plugin will send both
the selected code and your request to the GPT model. Upon receiving the
response, you can review it and decide if you want to replace the original
function with the suggested improvements.

This interactive flow allows you to tweak the prompt and visualize changes
effectively before finalizing any edits to your code.

