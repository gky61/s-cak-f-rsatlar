module.exports = {
  env: {
    es6: true,
    node: true,
  },
  parserOptions: {
    'ecmaVersion': 2020,
    'sourceType': 'module',
  },
  extends: [
    'eslint:recommended',
    'google',
  ],
  rules: {
    'no-restricted-globals': ['error', 'name', 'length'],
    'prefer-arrow-callback': 'error',
    'quotes': ['error', 'single', {'allowTemplateLiterals': true}],
    'require-jsdoc': 'off',
    'max-len': ['error', {'code': 120}],
  },
  overrides: [
    {
      files: ['**/*.spec.*', 'test.js', 'test_deal_notification.js'],
      env: {
        mocha: true,
      },
      rules: {
        'require-jsdoc': 'off',
        'max-len': 'off',
      },
    },
  ],
  globals: {},
};

