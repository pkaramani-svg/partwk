import React, { useState, useEffect, useRef } from 'react';
import { ChevronDown } from 'lucide-react';

const defaultCategoryNames = {
  'cat-productivity': 'Productivity',
  'cat-psychology': 'Psychology',
  'cat-personal-development': 'Personal Development',
  'cat-business': 'Business',
  'cat-leadership': 'Leadership',
  'cat-money-investing': 'Money & Investing',
  'cat-communication': 'Communication',
  'cat-health-wellness': 'Health & Wellness',
  'cat-technology-innovation': 'Technology & Innovation',
  'cat-biography-memoir': 'Biography & Memoir',
  'cat-modern-wisdom': 'Modern Wisdom',
  'cat-history-big-ideas': 'History & Big Ideas',
};

export const CategoryMultiSelect = ({
  categories = defaultCategoryNames,
  selectedCategories = ['cat-productivity'],
  onChange,
  disabled = false,
  id = 'category-multi-select'
}) => {
  const [isOpen, setIsOpen] = useState(false);
  const [validationMessage, setValidationMessage] = useState('');
  const containerRef = useRef(null);
  const triggerRef = useRef(null);

  // Summary text in closed/compact state
  const getSummaryText = () => {
    if (!selectedCategories || selectedCategories.length === 0) {
      return 'Select categories';
    }
    if (selectedCategories.length === 1) {
      const catId = selectedCategories[0];
      return categories[catId] || catId;
    }
    return `${selectedCategories.length} categories selected`;
  };

  // Close on outside click
  useEffect(() => {
    const handleOutsideClick = (event) => {
      if (containerRef.current && !containerRef.current.contains(event.target)) {
        setIsOpen(false);
        setValidationMessage('');
      }
    };

    if (isOpen) {
      document.addEventListener('mousedown', handleOutsideClick);
      document.addEventListener('touchstart', handleOutsideClick);
    }
    return () => {
      document.removeEventListener('mousedown', handleOutsideClick);
      document.removeEventListener('touchstart', handleOutsideClick);
    };
  }, [isOpen]);

  // Handle escape key
  const handleKeyDown = (e) => {
    if (e.key === 'Escape' && isOpen) {
      e.preventDefault();
      e.stopPropagation();
      setIsOpen(false);
      setValidationMessage('');
      triggerRef.current?.focus();
    } else if ((e.key === 'ArrowDown' || e.key === 'Enter' || e.key === ' ') && !isOpen) {
      e.preventDefault();
      setIsOpen(true);
    }
  };

  // Handle focusout when moving to another form control
  const handleBlur = (e) => {
    if (containerRef.current && !containerRef.current.contains(e.relatedTarget)) {
      setIsOpen(false);
      setValidationMessage('');
    }
  };

  const handleToggleCategory = (catId) => {
    const isSelected = selectedCategories.includes(catId);
    if (isSelected) {
      if (selectedCategories.length <= 1) {
        setValidationMessage('At least one category is required.');
        return;
      }
      setValidationMessage('');
      if (onChange) {
        onChange(selectedCategories.filter(c => c !== catId));
      }
    } else {
      setValidationMessage('');
      if (onChange) {
        onChange(Array.from(new Set([...selectedCategories, catId])));
      }
    }
  };

  return (
    <div
      ref={containerRef}
      onKeyDown={handleKeyDown}
      onBlur={handleBlur}
      style={{
        position: 'relative',
        width: '100%',
        userSelect: 'none'
      }}
    >
      <label
        htmlFor={`${id}-button`}
        style={{
          display: 'block',
          marginBottom: '8px',
          fontSize: '14px',
          fontWeight: '500',
          color: '#94A3B8'
        }}
      >
        Categories
      </label>

      {/* Compact Trigger Button */}
      <button
        ref={triggerRef}
        id={`${id}-button`}
        type="button"
        disabled={disabled}
        aria-haspopup="listbox"
        aria-expanded={isOpen}
        aria-controls={`${id}-listbox`}
        onClick={() => {
          if (!disabled) {
            setIsOpen(prev => !prev);
            setValidationMessage('');
          }
        }}
        style={{
          width: '100%',
          minHeight: '42px',
          padding: '10px 14px',
          background: '#1E293B',
          border: isOpen ? '1px solid #3B82F6' : '1px solid #334155',
          borderRadius: '8px',
          color: '#F8FAFC',
          fontSize: '14px',
          textAlign: 'left',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          cursor: disabled ? 'not-allowed' : 'pointer',
          outline: 'none',
          boxShadow: isOpen ? '0 0 0 2px rgba(59, 130, 246, 0.25)' : 'none',
          transition: 'border-color 0.15s ease, box-shadow 0.15s ease',
        }}
      >
        <span
          style={{
            overflow: 'hidden',
            textOverflow: 'ellipsis',
            whiteSpace: 'nowrap',
            fontWeight: selectedCategories.length > 0 ? '500' : 'normal',
            color: selectedCategories.length > 0 ? '#F8FAFC' : '#64748B'
          }}
        >
          {getSummaryText()}
        </span>
        <ChevronDown
          size={18}
          color="#94A3B8"
          style={{
            transform: isOpen ? 'rotate(180deg)' : 'rotate(0deg)',
            transition: 'transform 0.2s ease',
            flexShrink: 0,
            marginLeft: '8px'
          }}
          aria-hidden="true"
        />
      </button>

      {/* Inline Validation Notice */}
      {validationMessage && (
        <div
          role="alert"
          style={{
            marginTop: '4px',
            fontSize: '12px',
            color: '#F59E0B',
            display: 'flex',
            alignItems: 'center',
            gap: '4px'
          }}
        >
          <span>⚠</span>
          <span>{validationMessage}</span>
        </div>
      )}

      {/* Floating Dropdown List */}
      {isOpen && (
        <div
          id={`${id}-listbox`}
          role="listbox"
          aria-multiselectable="true"
          aria-label="Select categories"
          tabIndex={-1}
          style={{
            position: 'absolute',
            top: 'calc(100% + 4px)',
            left: 0,
            right: 0,
            zIndex: 100,
            background: '#0F172A',
            border: '1px solid #334155',
            borderRadius: '8px',
            boxShadow: '0 10px 25px -5px rgba(0, 0, 0, 0.7), 0 8px 10px -6px rgba(0, 0, 0, 0.5)',
            maxHeight: '260px',
            overflowY: 'auto',
            padding: '6px',
            display: 'flex',
            flexDirection: 'column',
            gap: '2px'
          }}
        >
          {Object.entries(categories).map(([catId, catName]) => {
            const isChecked = selectedCategories.includes(catId);
            return (
              <div
                key={catId}
                role="option"
                aria-selected={isChecked}
                tabIndex={0}
                onClick={(e) => {
                  e.stopPropagation();
                  handleToggleCategory(catId);
                }}
                onKeyDown={(e) => {
                  if (e.key === ' ' || e.key === 'Enter') {
                    e.preventDefault();
                    e.stopPropagation();
                    handleToggleCategory(catId);
                  }
                }}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '10px',
                  padding: '8px 12px',
                  borderRadius: '6px',
                  cursor: 'pointer',
                  background: isChecked ? 'rgba(59, 130, 246, 0.15)' : 'transparent',
                  color: isChecked ? '#93C5FD' : '#E2E8F0',
                  fontSize: '13.5px',
                  outline: 'none',
                  transition: 'background-color 0.15s ease'
                }}
                onMouseEnter={(e) => {
                  if (!isChecked) e.currentTarget.style.backgroundColor = '#1E293B';
                }}
                onMouseLeave={(e) => {
                  if (!isChecked) e.currentTarget.style.backgroundColor = 'transparent';
                }}
                onFocus={(e) => {
                  e.currentTarget.style.outline = '2px solid #3B82F6';
                  e.currentTarget.style.outlineOffset = '-1px';
                }}
                onBlur={(e) => {
                  e.currentTarget.style.outline = 'none';
                }}
              >
                <input
                  type="checkbox"
                  id={`${id}-opt-${catId}`}
                  checked={isChecked}
                  onChange={() => {
                    // Handled by parent div's onClick
                  }}
                  tabIndex={-1}
                  aria-hidden="true"
                  style={{
                    width: '16px',
                    height: '16px',
                    accentColor: '#3B82F6',
                    cursor: 'pointer',
                    flexShrink: 0
                  }}
                />
                <span style={{ flex: 1, userSelect: 'none' }}>{catName}</span>
                {isChecked && (
                  <span style={{ fontSize: '11px', fontWeight: 'bold', color: '#60A5FA' }}>✓</span>
                )}
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
};

export default CategoryMultiSelect;
