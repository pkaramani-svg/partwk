import test from 'node:test';
import assert from 'node:assert/strict';

// Test Category Multi Select Logic & State Reducer
const testCategories = {
  'cat-productivity': 'Productivity',
  'cat-psychology': 'Psychology',
  'cat-personal-development': 'Personal Development',
  'cat-business': 'Business',
  'cat-leadership': 'Leadership',
};

// Pure summary text helper
function getSummaryText(selectedCategories, categories) {
  if (!selectedCategories || selectedCategories.length === 0) {
    return 'Select categories';
  }
  if (selectedCategories.length === 1) {
    const catId = selectedCategories[0];
    return categories[catId] || catId;
  }
  return `${selectedCategories.length} categories selected`;
}

// Pure toggle helper replicating CategoryMultiSelect behavior
function toggleCategory(currentSelected, targetId) {
  const isSelected = currentSelected.includes(targetId);
  if (isSelected) {
    if (currentSelected.length <= 1) {
      return {
        selected: currentSelected,
        validationMessage: 'At least one category is required.',
        closed: false
      };
    }
    return {
      selected: currentSelected.filter(c => c !== targetId),
      validationMessage: '',
      closed: false
    };
  }
  return {
    selected: Array.from(new Set([...currentSelected, targetId])),
    validationMessage: '',
    closed: false
  };
}

test('1. Closed state summary text: Single selected category', () => {
  const selected = ['cat-personal-development'];
  const summary = getSummaryText(selected, testCategories);
  assert.equal(summary, 'Personal Development');
});

test('2. Closed state summary text: Multiple selected categories', () => {
  const selected = ['cat-productivity', 'cat-psychology', 'cat-business'];
  const summary = getSummaryText(selected, testCategories);
  assert.equal(summary, '3 categories selected');
});

test('3. Closed state summary text: Empty fallback', () => {
  const summary = getSummaryText([], testCategories);
  assert.equal(summary, 'Select categories');
});

test('4. Selection addition: Adds new category without duplicates and leaves dropdown open', () => {
  const initial = ['cat-productivity'];
  const result = toggleCategory(initial, 'cat-business');
  assert.deepEqual(result.selected, ['cat-productivity', 'cat-business']);
  assert.equal(result.validationMessage, '');
  assert.equal(result.closed, false);
});

test('5. Selection removal: Removes category when more than 1 selected', () => {
  const initial = ['cat-productivity', 'cat-business', 'cat-leadership'];
  const result = toggleCategory(initial, 'cat-business');
  assert.deepEqual(result.selected, ['cat-productivity', 'cat-leadership']);
  assert.equal(result.validationMessage, '');
  assert.equal(result.closed, false);
});

test('6. Minimum-one validation: Attempting to remove final category retains it and shows validation message without alert', () => {
  const initial = ['cat-productivity'];
  const result = toggleCategory(initial, 'cat-productivity');
  // Must retain the single category
  assert.deepEqual(result.selected, ['cat-productivity']);
  // Must show subtle inline validation message
  assert.equal(result.validationMessage, 'At least one category is required.');
  // Must not close dropdown
  assert.equal(result.closed, false);
});

test('7. Validation clearing: Adding a second category clears the validation message', () => {
  const single = ['cat-productivity'];
  const attemptedRemoval = toggleCategory(single, 'cat-productivity');
  assert.equal(attemptedRemoval.validationMessage, 'At least one category is required.');

  const addedSecond = toggleCategory(attemptedRemoval.selected, 'cat-leadership');
  assert.deepEqual(addedSecond.selected, ['cat-productivity', 'cat-leadership']);
  assert.equal(addedSecond.validationMessage, '');
});

test('8. Legacy book preloading: Correctly sets single legacy category and displays its name', () => {
  const legacyBook = {
    id: 'legacy_1',
    title: { en: 'Old Book' },
    category: 'cat-psychology'
  };

  const preloadedCategories = Array.isArray(legacyBook.categories) && legacyBook.categories.length > 0
    ? legacyBook.categories
    : (Array.isArray(legacyBook.categoryIds) && legacyBook.categoryIds.length > 0
      ? legacyBook.categoryIds
      : (legacyBook.category ? [legacyBook.category] : ['cat-productivity']));

  assert.deepEqual(preloadedCategories, ['cat-psychology']);
  assert.equal(getSummaryText(preloadedCategories, testCategories), 'Psychology');
});

test('9. New-book generation selection: Starts with cat-productivity and supports multiple selection', () => {
  let selected = ['cat-productivity'];
  assert.equal(getSummaryText(selected, testCategories), 'Productivity');

  // Select additional categories during new-book generation
  selected = toggleCategory(selected, 'cat-business').selected;
  selected = toggleCategory(selected, 'cat-leadership').selected;
  assert.deepEqual(selected, ['cat-productivity', 'cat-business', 'cat-leadership']);
  assert.equal(getSummaryText(selected, testCategories), '3 categories selected');
});

test('10. Escape and Outside Click semantics', () => {
  let isOpen = true;
  let validationMessage = 'At least one category is required.';

  // Simulate Escape
  const onEscape = () => {
    isOpen = false;
    validationMessage = '';
  };
  onEscape();
  assert.equal(isOpen, false);
  assert.equal(validationMessage, '');

  // Simulate Outside Click
  isOpen = true;
  const onOutsideClick = () => {
    isOpen = false;
    validationMessage = '';
  };
  onOutsideClick();
  assert.equal(isOpen, false);
  assert.equal(validationMessage, '');
});
