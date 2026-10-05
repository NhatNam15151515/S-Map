FIREBASE_PROJECT=vn-s-map
DEV_BUNDLE_ID=com.vnsmap.app.dev
PRO_BUNDLE_ID=com.vnsmap.app

DEV_SUFFIX=dev
PRO_SUFFIX=pro

SUBMIT_ACCOUNT=developer@vnsmap.com
PASSWORD_ACCOUNT=<APPLE_PASSWORD>

FIREBASE_APP_ID=1:495182969568:android:c4083fca783d0d9cd46e85

gen_locale:
	flutter pub get
	flutter pub run easy_localization:generate -S assets/translations -f keys -o locale_keys.g.dart
	flutter pub run easy_localization:generate -S assets/translations

create_splash:
	flutter pub run flutter_native_splash:create

run_dev:
	flutter run -t lib/main.dart --dart-define-from-file=.env/dev.json

run_pro:
	flutter run -t lib/main.dart --dart-define-from-file=.env/pro.json

dev_ipa:
	flutter build ipa -t lib/main.dart --dart-define-from-file=.env/dev.json

pro_ipa:
	flutter build ipa -t lib/main.dart --dart-define-from-file=.env/pro.json

dev_apk:
	flutter build apk -t lib/main.dart --dart-define-from-file=.env/dev.json

prod_apk:
	flutter build apk -t lib/main.dart --dart-define-from-file=.env/pro.json

dev_aab:
	flutter build appbundle -t lib/main.dart --dart-define-from-file=.env/dev.json

pro_aab:
	flutter build appbundle -t lib/main.dart --dart-define-from-file=.env/pro.json

firebase_dev_config:
	flutterfire config \
      --project=$(FIREBASE_PROJECT) \
      --out=lib/flavor/flutterfire_options/firebase_options_$(DEV_SUFFIX).dart \
      --ios-bundle-id=$(DEV_BUNDLE_ID)\
      --android-app-id=$(DEV_BUNDLE_ID)

firebase_pro_config:
	flutterfire config \
      --project=$(FIREBASE_PROJECT) \
      --out=lib/flavor/flutterfire_options/firebase_options_$(PRO_SUFFIX).dart \
      --ios-bundle-id=$(PRO_BUNDLE_ID) \
      --android-app-id=$(PRO_BUNDLE_ID)

firebase_distribute_dev:
	firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk  \
		--app $(FIREBASE_APP_ID)  \
		--release-notes ""

submit_ipa:
	xcrun altool --upload-app --type ios -f build/ios/ipa/*.ipa --username $(SUBMIT_ACCOUNT) --password $(PASSWORD_ACCOUNT)

submit_dev:
	make dev_ipa && make submit_ipa
	make dev_apk && make firebase_distribute_dev

submit_pro:
	make pro_ipa && make submit_ipa
	make prod_apk && make pro_aab

clean:
	flutter clean && flutter pub get

build_data:
	python data-pipeline/build_all_data.py --region all

build_data_hcm:
	python data-pipeline/build_all_data.py --region metro_hcm
