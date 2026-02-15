#!/usr/bin/env python3
"""
NoteWall Localization Script
Extracts hardcoded strings from Swift files and generates complete translations
"""

import re
import os
from pathlib import Path
from typing import Dict, List, Set
import json

# Deep translation dictionaries for each language
TRANSLATIONS = {
    "de": {  # German
        # Common UI
        "Continue": "Weiter",
        "Cancel": "Abbrechen",
        "Delete": "Löschen",
        "Done": "Fertig",
        "Close": "Schließen",
        "OK": "OK",
        "Skip": "Überspringen",
        "Next": "Weiter",
        "Yes": "Ja",
        "No": "Nein",
        "Send": "Senden",
        "Apply": "Anwenden",
        "Save": "Speichern",
        "Loading...": "Lädt...",
        "Sending...": "Wird gesendet...",
        "Updating…": "Aktualisiert...",
        "Generating...": "Generiert...",
        "Saving…": "Speichert...",
        "Preview": "Vorschau",
        "Install": "Installieren",
        "Error": "Fehler",
        "Success": "Erfolg",
        "Warning": "Warnung",
        "Info": "Info",
        
        # Auto-Fix Workflow
        "Issues found:": "Gefundene Probleme:",
        "Contact Support": "Support kontaktieren",
        "Start Auto-Fix": "Auto-Fix starten",
        
        # Delete/Wallpaper alerts
        "Delete Previous Wallpaper?": "Vorheriges Hintergrundbild löschen?",
        "To avoid filling your Photos library, NoteWall can delete the previous wallpaper. If you continue, iOS will ask for permission to delete the photo.": "Um deine Fotomediathek nicht zu füllen, kann NoteWall das vorherige Hintergrundbild löschen. Wenn du fortsetzt, wird iOS um Erlaubnis zum Löschen des Fotos bitten.",
        "Delete Note?": "Notiz löschen?",
        "Are you sure you want to delete this note? This action cannot be undone.": "Bist du sicher, dass du diese Notiz löschen möchtest? Diese Aktion kann nicht rückgängig gemacht werden.",
        "Delete Selected Notes?": "Ausgewählte Notizen löschen?",
        "Are you sure you want to delete the selected notes? This action cannot be undone.": "Bist du sicher, dass du die ausgewählten Notizen löschen möchtest? Diese Aktion kann nicht rückgängig gemacht werden.",
        "Wallpaper Full": "Hintergrundbild voll",
        "Your wallpaper has reached its maximum capacity. Complete or delete existing notes to add new ones.": "Dein Hintergrundbild hat seine maximale Kapazität erreicht. Erledige oder lösche bestehende Notizen, um neue hinzuzufügen.",
        
        # Home screen
        "No notes yet": "Noch keine Notizen",
        "Add a note below to get started": "Füge unten eine Notiz hinzu, um zu beginnen",
        "Delete (%lld)": "Löschen (%lld)",
        "Wallpaper Not Showing?": "Hintergrundbild wird nicht angezeigt?",
        "We can help you fix it in just a few steps.": "Wir können dir helfen, es in wenigen Schritten zu beheben.",
        "Get Help": "Hilfe erhalten",
        "Friendly Reminder": "Freundliche Erinnerung",
        "Your free trial subscription will be ending soon.": "Dein kostenloses Testabonnement endet bald.",
        "Great! You added your first note": "Großartig! Du hast deine erste Notiz hinzugefügt",
        "Add more notes using the + button, then tap \"Update Wallpaper\" to apply them to your lock screen.": "Füge weitere Notizen mit der +-Schaltfläche hinzu und tippe dann auf \"Hintergrundbild aktualisieren\", um sie auf deinen Sperrbildschirm anzuwenden.",
        
        # Delete loading
        "Deleting notes...": "Notizen werden gelöscht...",
        "Notes Deleted!": "Notizen gelöscht!",
        "sec": "Sek.",
        
        # Device info (debug)
        "Device Category:": "Gerätekategorie:",
        "Screen:": "Bildschirm:",
        "Scale Factor:": "Skalierungsfaktor:",
        "Is Compact:": "Ist kompakt:",
        "Max Video Height:": "Max. Videohöhe:",
        
        # Exit feedback
        "Before You Go...": "Bevor du gehst...",
        "Hey! I built NoteWall myself and I'm genuinely trying to make it better every day.": "Hey! Ich habe NoteWall selbst entwickelt und versuche wirklich, es jeden Tag besser zu machen.",
        "If something didn't work or felt off, I really want to know. Your feedback directly shapes what I fix next.": "Wenn etwas nicht funktioniert hat oder sich merkwürdig anfühlte, möchte ich es wirklich wissen. Dein Feedback bestimmt direkt, was ich als nächstes behebe.",
        "What could be better?": "Was könnte besser sein?",
        "Tell me what went wrong...": "Sag mir, was schief gelaufen ist...",
        "Send Feedback": "Feedback senden",
        "Maybe Later": "Vielleicht später",
        "Thanks for Your Feedback!": "Danke für dein Feedback!",
        "I'll read this personally and work on making NoteWall better.": "Ich werde das persönlich lesen und daran arbeiten, NoteWall besser zu machen.",
        
        # Legal
        "Privacy Policy": "Datenschutzrichtlinie",
        "Terms of Service": "Nutzungsbedingungen",
        "End User License Agreement": "Endbenutzer-Lizenzvereinbarung",
        
        # Paywall
        "Unlock Full Access": "Vollen Zugriff freischalten",
        "Get Premium": "Premium erhalten",
        "Restore Purchase": "Kauf wiederherstellen",
        "Already subscribed?": "Schon abonniert?",
        "Unlimited wallpaper updates": "Unbegrenzte Hintergrundbild-Updates",
        "Custom fonts & styles": "Benutzerdefinierte Schriftarten & Stile",
        "Priority support": "Vorrangiger Support",
        "No ads, ever": "Keine Werbung, niemals",
        "Start Free Trial": "Kostenlose Testversion starten",
        "Subscribe": "Abonnieren",
        "Lifetime Access": "Lebenslanger Zugriff",
        "Monthly": "Monatlich",
        "Yearly": "Jährlich",
        
        # Settings
        "Settings": "Einstellungen",
        "Wallpaper Settings": "Hintergrundbild-Einstellungen",
        "Text Style": "Textstil",
        "Help & Support": "Hilfe & Support",
        "About": "Über",
        "Version": "Version",
        "Build": "Build",
        "Share NoteWall": "NoteWall teilen",
        "Rate Us": "Bewerte uns",
        "Send us Feedback": "Feedback senden",
        
        # Onboarding specific
        "Welcome to NoteWall": "Willkommen bei NoteWall",
        "Never forget what matters": "Vergiss nie, was wichtig ist",
        "Your notes, always visible": "Deine Notizen, immer sichtbar",
        "Let's get started": "Lass uns beginnen",
        "What's your name?": "Wie heißt du?",
        "Enter your name": "Gib deinen Namen ein",
        "Skip this step": "Diesen Schritt überspringen",
        "Grant Permissions First": "Erteile zuerst die Berechtigungen",
        "Permissions granted!": "Berechtigungen erteilt!",
        "Allow ALL Permissions": "ALLE Berechtigungen erlauben",
        "Permission popups appear here": "Berechtigungs-Popups erscheinen hier",
        "click ALLOW for all": "ERLAUBEN für alle anklicken",
        "(this is how it should look)": "(so sollte es aussehen)",
        "Start Using NoteWall": "NoteWall verwenden",
        
        # Apology flow
        "We Owe You an Apology": "Wir schulden dir eine Entschuldigung",
        "You might have experienced a bug that prevented your wallpaper from updating. That's on us — let's get you back on track.": "Möglicherweise hast du einen Fehler erlebt, der die Aktualisierung deines Hintergrundbilds verhindert hat. Das liegt an uns – lass uns das in Ordnung bringen.",
        "What Happened?": "Was ist passiert?",
        "The Issue": "Das Problem",
        "A technical bug prevented wallpapers from updating correctly for some users.": "Ein technischer Fehler verhinderte die korrekte Aktualisierung von Hintergrundbildern für einige Benutzer.",
        "Your Notes Are Safe": "Deine Notizen sind sicher",
        "All your notes and data are perfectly intact.": "Alle deine Notizen und Daten sind vollkommen intakt.",
        "The Fix": "Die Lösung",
        "We've completely rebuilt the system. It now works faster and more reliably.": "Wir haben das System komplett neu aufgebaut. Es funktioniert jetzt schneller und zuverlässiger.",
        "What You Need to Do": "Was du tun musst",
        "Quick 1-minute setup to install the new system.": "Schnelle 1-Minuten-Einrichtung zur Installation des neuen Systems.",
        "Let's Fix This Together": "Lass uns das gemeinsam beheben",
        "I'll Handle It Later": "Ich kümmere mich später darum",
        
        # What's New
        "What's New": "Was ist neu",
        "New in this version": "Neu in dieser Version",
        "Improvements and bug fixes": "Verbesserungen und Fehlerbehebungen",
        "Got It": "Verstanden",
        
        # Troubleshooting
        "Troubleshooting": "Fehlerbehebung",
        "Common Issues": "Häufige Probleme",
        "Wallpaper not updating?": "Hintergrundbild wird nicht aktualisiert?",
        "Try these steps:": "Versuche diese Schritte:",
        "Restart your device": "Starte dein Gerät neu",
        "Reinstall the shortcut": "Installiere die Verknüpfung neu",
        "Check permissions": "Überprüfe die Berechtigungen",
        "Still having issues?": "Hast du immer noch Probleme?",
        "Contact our support team": "Kontaktiere unser Support-Team",
        
        # Subscription feedback
        "Why are you canceling?": "Warum kündigst du?",
        "Your feedback helps us improve": "Dein Feedback hilft uns bei der Verbesserung",
        "Too expensive": "Zu teuer",
        "Not using it enough": "Nutze es nicht genug",
        "Technical issues": "Technische Probleme",
        "Missing features": "Fehlende Funktionen",
        "Other reason": "Anderer Grund",
        "Tell us more (optional)": "Erzähl uns mehr (optional)",
        "Submit Feedback": "Feedback absenden",
        "Thank you for your feedback": "Danke für dein Feedback",
    },
    
    "es": {  # Spanish
        # Common UI
        "Continue": "Continuar",
        "Cancel": "Cancelar",
        "Delete": "Eliminar",
        "Done": "Listo",
        "Close": "Cerrar",
        "OK": "OK",
        "Skip": "Omitir",
        "Next": "Siguiente",
        "Yes": "Sí",
        "No": "No",
        "Send": "Enviar",
        "Apply": "Aplicar",
        "Save": "Guardar",
        "Loading...": "Cargando...",
        "Sending...": "Enviando...",
        "Updating…": "Actualizando...",
        "Generating...": "Generando...",
        "Saving…": "Guardando...",
        "Preview": "Vista previa",
        "Install": "Instalar",
        "Error": "Error",
        "Success": "Éxito",
        "Warning": "Advertencia",
        "Info": "Info",
        
        # Auto-Fix Workflow
        "Issues found:": "Problemas encontrados:",
        "Contact Support": "Contactar soporte",
        "Start Auto-Fix": "Iniciar corrección automática",
        
        # Delete/Wallpaper alerts
        "Delete Previous Wallpaper?": "¿Eliminar fondo anterior?",
        "To avoid filling your Photos library, NoteWall can delete the previous wallpaper. If you continue, iOS will ask for permission to delete the photo.": "Para evitar llenar tu biblioteca de Fotos, NoteWall puede eliminar el fondo anterior. Si continúas, iOS pedirá permiso para eliminar la foto.",
        "Delete Note?": "¿Eliminar nota?",
        "Are you sure you want to delete this note? This action cannot be undone.": "¿Estás seguro de que quieres eliminar esta nota? Esta acción no se puede deshacer.",
        "Delete Selected Notes?": "¿Eliminar notas seleccionadas?",
        "Are you sure you want to delete the selected notes? This action cannot be undone.": "¿Estás seguro de que quieres eliminar las notas seleccionadas? Esta acción no se puede deshacer.",
        "Wallpaper Full": "Fondo lleno",
        "Your wallpaper has reached its maximum capacity. Complete or delete existing notes to add new ones.": "Tu fondo ha alcanzado su capacidad máxima. Completa o elimina notas existentes para añadir nuevas.",
        
        # Home screen
        "No notes yet": "Sin notas aún",
        "Add a note below to get started": "Añade una nota abajo para empezar",
        "Delete (%lld)": "Eliminar (%lld)",
        "Wallpaper Not Showing?": "¿El fondo no se muestra?",
        "We can help you fix it in just a few steps.": "Podemos ayudarte a solucionarlo en pocos pasos.",
        "Get Help": "Obtener ayuda",
        "Friendly Reminder": "Recordatorio amistoso",
        "Your free trial subscription will be ending soon.": "Tu período de prueba gratuito terminará pronto.",
        "Great! You added your first note": "¡Genial! Añadiste tu primera nota",
        "Add more notes using the + button, then tap \"Update Wallpaper\" to apply them to your lock screen.": "Añade más notas usando el botón + y luego toca \"Actualizar fondo\" para aplicarlas a tu pantalla de bloqueo.",
        
        # Delete loading
        "Deleting notes...": "Eliminando notas...",
        "Notes Deleted!": "¡Notas eliminadas!",
        "sec": "seg",
        
        # Device info (debug)
        "Device Category:": "Categoría del dispositivo:",
        "Screen:": "Pantalla:",
        "Scale Factor:": "Factor de escala:",
        "Is Compact:": "Es compacto:",
        "Max Video Height:": "Altura máx. de video:",
        
        # Exit feedback
        "Before You Go...": "Antes de irte...",
        "Hey! I built NoteWall myself and I'm genuinely trying to make it better every day.": "¡Hola! Construí NoteWall yo mismo y realmente intento mejorarlo cada día.",
        "If something didn't work or felt off, I really want to know. Your feedback directly shapes what I fix next.": "Si algo no funcionó o se sintió extraño, realmente quiero saberlo. Tu opinión determina directamente lo que arreglo después.",
        "What could be better?": "¿Qué podría ser mejor?",
        "Tell me what went wrong...": "Cuéntame qué salió mal...",
        "Send Feedback": "Enviar opinión",
        "Maybe Later": "Quizás más tarde",
        "Thanks for Your Feedback!": "¡Gracias por tu opinión!",
        "I'll read this personally and work on making NoteWall better.": "Leeré esto personalmente y trabajaré en mejorar NoteWall.",
        
        # Legal
        "Privacy Policy": "Política de privacidad",
        "Terms of Service": "Términos de servicio",
        "End User License Agreement": "Acuerdo de licencia de usuario final",
        
        # Paywall
        "Unlock Full Access": "Desbloquear acceso completo",
        "Get Premium": "Obtener Premium",
        "Restore Purchase": "Restaurar compra",
        "Already subscribed?": "¿Ya estás suscrito?",
        "Unlimited wallpaper updates": "Actualizaciones ilimitadas de fondos",
        "Custom fonts & styles": "Fuentes y estilos personalizados",
        "Priority support": "Soporte prioritario",
        "No ads, ever": "Sin anuncios, nunca",
        "Start Free Trial": "Iniciar prueba gratuita",
        "Subscribe": "Suscribirse",
        "Lifetime Access": "Acceso de por vida",
        "Monthly": "Mensual",
        "Yearly": "Anual",
        
        # Settings
        "Settings": "Ajustes",
        "Wallpaper Settings": "Ajustes de fondo",
        "Text Style": "Estilo de texto",
        "Help & Support": "Ayuda y soporte",
        "About": "Acerca de",
        "Version": "Versión",
        "Build": "Compilación",
        "Share NoteWall": "Compartir NoteWall",
        "Rate Us": "Califícanos",
        "Send us Feedback": "Enviar opinión",
        
        # Onboarding specific
        "Welcome to NoteWall": "Bienvenido a NoteWall",
        "Never forget what matters": "Nunca olvides lo que importa",
        "Your notes, always visible": "Tus notas, siempre visibles",
        "Let's get started": "Empecemos",
        "What's your name?": "¿Cómo te llamas?",
        "Enter your name": "Ingresa tu nombre",
        "Skip this step": "Omitir este paso",
        "Grant Permissions First": "Primero concede los permisos",
        "Permissions granted!": "¡Permisos concedidos!",
        "Allow ALL Permissions": "Permitir TODOS los permisos",
        "Permission popups appear here": "Los permisos aparecen aquí",
        "click ALLOW for all": "toca PERMITIR en todos",
        "(this is how it should look)": "(así debería verse)",
        "Start Using NoteWall": "Empezar a usar NoteWall",
        
        # Apology flow
        "We Owe You an Apology": "Te debemos una disculpa",
        "You might have experienced a bug that prevented your wallpaper from updating. That's on us — let's get you back on track.": "Puede que hayas experimentado un error que impidió actualizar tu fondo. Eso es culpa nuestra — pongámoslo en orden.",
        "What Happened?": "¿Qué pasó?",
        "The Issue": "El problema",
        "A technical bug prevented wallpapers from updating correctly for some users.": "Un error técnico impidió que los fondos se actualizaran correctamente para algunos usuarios.",
        "Your Notes Are Safe": "Tus notas están seguras",
        "All your notes and data are perfectly intact.": "Todas tus notas y datos están perfectamente intactos.",
        "The Fix": "La solución",
        "We've completely rebuilt the system. It now works faster and more reliably.": "Hemos reconstruido completamente el sistema. Ahora funciona más rápido y de manera más confiable.",
        "What You Need to Do": "Lo que necesitas hacer",
        "Quick 1-minute setup to install the new system.": "Configuración rápida de 1 minuto para instalar el nuevo sistema.",
        "Let's Fix This Together": "Arreglemos esto juntos",
        "I'll Handle It Later": "Lo manejaré más tarde",
        
        # What's New
        "What's New": "Novedades",
        "New in this version": "Nuevo en esta versión",
        "Improvements and bug fixes": "Mejoras y correcciones de errores",
        "Got It": "Entendido",
        
        # Troubleshooting
        "Troubleshooting": "Solución de problemas",
        "Common Issues": "Problemas comunes",
        "Wallpaper not updating?": "¿El fondo no se actualiza?",
        "Try these steps:": "Prueba estos pasos:",
        "Restart your device": "Reinicia tu dispositivo",
        "Reinstall the shortcut": "Reinstala el atajo",
        "Check permissions": "Verifica los permisos",
        "Still having issues?": "¿Sigues teniendo problemas?",
        "Contact our support team": "Contacta a nuestro equipo de soporte",
        
        # Subscription feedback
        "Why are you canceling?": "¿Por qué estás cancelando?",
        "Your feedback helps us improve": "Tu opinión nos ayuda a mejorar",
        "Too expensive": "Demasiado caro",
        "Not using it enough": "No lo uso suficiente",
        "Technical issues": "Problemas técnicos",
        "Missing features": "Faltan características",
        "Other reason": "Otra razón",
        "Tell us more (optional)": "Cuéntanos más (opcional)",
        "Submit Feedback": "Enviar opinión",
        "Thank you for your feedback": "Gracias por tu opinión",
    },
    
    "fr": {  # French
        # Common UI
        "Continue": "Continuer",
        "Cancel": "Annuler",
        "Delete": "Supprimer",
        "Done": "Terminé",
        "Close": "Fermer",
        "OK": "OK",
        "Skip": "Passer",
        "Next": "Suivant",
        "Yes": "Oui",
        "No": "Non",
        "Send": "Envoyer",
        "Apply": "Appliquer",
        "Save": "Enregistrer",
        "Loading...": "Chargement...",
        "Sending...": "Envoi...",
        "Updating…": "Mise à jour...",
        "Generating...": "Génération...",
        "Saving…": "Enregistrement...",
        "Preview": "Aperçu",
        "Install": "Installer",
        "Error": "Erreur",
        "Success": "Succès",
        "Warning": "Avertissement",
        "Info": "Info",
        
        # Auto-Fix Workflow
        "Issues found:": "Problèmes trouvés:",
        "Contact Support": "Contacter le support",
        "Start Auto-Fix": "Démarrer la correction automatique",
        
        # Delete/Wallpaper alerts
        "Delete Previous Wallpaper?": "Supprimer le fond d'écran précédent?",
        "To avoid filling your Photos library, NoteWall can delete the previous wallpaper. If you continue, iOS will ask for permission to delete the photo.": "Pour éviter de remplir votre photothèque, NoteWall peut supprimer le fond d'écran précédent. Si vous continuez, iOS demandera la permission de supprimer la photo.",
        "Delete Note?": "Supprimer la note?",
        "Are you sure you want to delete this note? This action cannot be undone.": "Êtes-vous sûr de vouloir supprimer cette note? Cette action ne peut pas être annulée.",
        "Delete Selected Notes?": "Supprimer les notes sélectionnées?",
        "Are you sure you want to delete the selected notes? This action cannot be undone.": "Êtes-vous sûr de vouloir supprimer les notes sélectionnées? Cette action ne peut pas être annulée.",
        "Wallpaper Full": "Fond d'écran plein",
        "Your wallpaper has reached its maximum capacity. Complete or delete existing notes to add new ones.": "Votre fond d'écran a atteint sa capacité maximale. Complétez ou supprimez les notes existantes pour en ajouter de nouvelles.",
        
        # Home screen
        "No notes yet": "Pas encore de notes",
        "Add a note below to get started": "Ajoutez une note ci-dessous pour commencer",
        "Delete (%lld)": "Supprimer (%lld)",
        "Wallpaper Not Showing?": "Le fond d'écran ne s'affiche pas?",
        "We can help you fix it in just a few steps.": "Nous pouvons vous aider à le corriger en quelques étapes.",
        "Get Help": "Obtenir de l'aide",
        "Friendly Reminder": "Rappel amical",
        "Your free trial subscription will be ending soon.": "Votre période d'essai gratuite se terminera bientôt.",
        "Great! You added your first note": "Génial! Vous avez ajouté votre première note",
        "Add more notes using the + button, then tap \"Update Wallpaper\" to apply them to your lock screen.": "Ajoutez plus de notes avec le bouton + puis appuyez sur \"Mettre à jour le fond d'écran\" pour les appliquer à votre écran de verrouillage.",
        
        # Delete loading
        "Deleting notes...": "Suppression des notes...",
        "Notes Deleted!": "Notes supprimées!",
        "sec": "sec",
        
        # Device info (debug)
        "Device Category:": "Catégorie d'appareil:",
        "Screen:": "Écran:",
        "Scale Factor:": "Facteur d'échelle:",
        "Is Compact:": "Est compact:",
        "Max Video Height:": "Hauteur vidéo max:",
        
        # Exit feedback
        "Before You Go...": "Avant de partir...",
        "Hey! I built NoteWall myself and I'm genuinely trying to make it better every day.": "Salut! J'ai créé NoteWall moi-même et j'essaie vraiment de l'améliorer chaque jour.",
        "If something didn't work or felt off, I really want to know. Your feedback directly shapes what I fix next.": "Si quelque chose n'a pas fonctionné ou semblait bizarre, je veux vraiment le savoir. Vos commentaires déterminent directement ce que je corrige ensuite.",
        "What could be better?": "Qu'est-ce qui pourrait être mieux?",
        "Tell me what went wrong...": "Dites-moi ce qui n'a pas marché...",
        "Send Feedback": "Envoyer des commentaires",
        "Maybe Later": "Peut-être plus tard",
        "Thanks for Your Feedback!": "Merci pour vos commentaires!",
        "I'll read this personally and work on making NoteWall better.": "Je lirai ceci personnellement et travaillerai à améliorer NoteWall.",
        
        # Legal
        "Privacy Policy": "Politique de confidentialité",
        "Terms of Service": "Conditions d'utilisation",
        "End User License Agreement": "Accord de licence utilisateur final",
        
        # Paywall
        "Unlock Full Access": "Débloquer l'accès complet",
        "Get Premium": "Obtenir Premium",
        "Restore Purchase": "Restaurer l'achat",
        "Already subscribed?": "Déjà abonné?",
        "Unlimited wallpaper updates": "Mises à jour illimitées de fond d'écran",
        "Custom fonts & styles": "Polices et styles personnalisés",
        "Priority support": "Support prioritaire",
        "No ads, ever": "Pas de publicité, jamais",
        "Start Free Trial": "Démarrer l'essai gratuit",
        "Subscribe": "S'abonner",
        "Lifetime Access": "Accès à vie",
        "Monthly": "Mensuel",
        "Yearly": "Annuel",
        
        # Settings
        "Settings": "Réglages",
        "Wallpaper Settings": "Paramètres du fond d'écran",
        "Text Style": "Style de texte",
        "Help & Support": "Aide et support",
        "About": "À propos",
        "Version": "Version",
        "Build": "Build",
        "Share NoteWall": "Partager NoteWall",
        "Rate Us": "Évaluez-nous",
        "Send us Feedback": "Envoyez-nous des commentaires",
        
        # Onboarding specific
        "Welcome to NoteWall": "Bienvenue sur NoteWall",
        "Never forget what matters": "N'oubliez jamais ce qui compte",
        "Your notes, always visible": "Vos notes, toujours visibles",
        "Let's get started": "Commençons",
        "What's your name?": "Quel est votre nom?",
        "Enter your name": "Entrez votre nom",
        "Skip this step": "Passer cette étape",
        "Grant Permissions First": "Accordez d'abord les autorisations",
        "Permissions granted!": "Autorisations accordées!",
        "Allow ALL Permissions": "Autoriser TOUTES les autorisations",
        "Permission popups appear here": "Les autorisations apparaissent ici",
        "click ALLOW for all": "appuyez sur AUTORISER pour tous",
        "(this is how it should look)": "(voici à quoi cela devrait ressembler)",
        "Start Using NoteWall": "Commencer à utiliser NoteWall",
        
        # Apology flow
        "We Owe You an Apology": "Nous vous devons des excuses",
        "You might have experienced a bug that prevented your wallpaper from updating. That's on us — let's get you back on track.": "Vous avez peut-être rencontré un bug qui a empêché la mise à jour de votre fond d'écran. C'est de notre faute — remettons les choses en ordre.",
        "What Happened?": "Que s'est-il passé?",
        "The Issue": "Le problème",
        "A technical bug prevented wallpapers from updating correctly for some users.": "Un bug technique a empêché les fonds d'écran de se mettre à jour correctement pour certains utilisateurs.",
        "Your Notes Are Safe": "Vos notes sont en sécurité",
        "All your notes and data are perfectly intact.": "Toutes vos notes et données sont parfaitement intactes.",
        "The Fix": "La solution",
        "We've completely rebuilt the system. It now works faster and more reliably.": "Nous avons complètement reconstruit le système. Il fonctionne maintenant plus rapidement et de manière plus fiable.",
        "What You Need to Do": "Ce que vous devez faire",
        "Quick 1-minute setup to install the new system.": "Configuration rapide d'1 minute pour installer le nouveau système.",
        "Let's Fix This Together": "Réparons cela ensemble",
        "I'll Handle It Later": "Je m'en occuperai plus tard",
        
        # What's New
        "What's New": "Nouveautés",
        "New in this version": "Nouveau dans cette version",
        "Improvements and bug fixes": "Améliorations et corrections de bugs",
        "Got It": "Compris",
        
        # Troubleshooting
        "Troubleshooting": "Dépannage",
        "Common Issues": "Problèmes courants",
        "Wallpaper not updating?": "Le fond d'écran ne se met pas à jour?",
        "Try these steps:": "Essayez ces étapes:",
        "Restart your device": "Redémarrez votre appareil",
        "Reinstall the shortcut": "Réinstallez le raccourci",
        "Check permissions": "Vérifiez les autorisations",
        "Still having issues?": "Vous avez toujours des problèmes?",
        "Contact our support team": "Contactez notre équipe de support",
        
        # Subscription feedback
        "Why are you canceling?": "Pourquoi annulez-vous?",
        "Your feedback helps us improve": "Vos commentaires nous aident à nous améliorer",
        "Too expensive": "Trop cher",
        "Not using it enough": "Je ne l'utilise pas assez",
        "Technical issues": "Problèmes techniques",
        "Missing features": "Fonctionnalités manquantes",
        "Other reason": "Autre raison",
        "Tell us more (optional)": "Dites-nous en plus (optionnel)",
        "Submit Feedback": "Soumettre des commentaires",
        "Thank you for your feedback": "Merci pour vos commentaires",
    },
}


def extract_hardcoded_strings(swift_file_path: str) -> Set[str]:
    """Extract hardcoded Text() strings from Swift file"""
    strings = set()
    
    with open(swift_file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Pattern for Text("...")
    text_pattern = r'Text\("([^"]+)"\)'
    matches = re.findall(text_pattern, content)
    strings.update(matches)
    
    # Pattern for title: Text("...")
    title_pattern = r'title:\s*Text\("([^"]+)"\)'
    matches = re.findall(title_pattern, content)
    strings.update(matches)
    
    # Pattern for message: Text("...")
    message_pattern = r'message:\s*Text\("([^"]+)"\)'
    matches = re.findall(message_pattern, content)
    strings.update(matches)
    
    # Pattern for .destructive(Text("..."))
    destructive_pattern = r'\.\w+\(Text\("([^"]+)"\)\)'
    matches = re.findall(destructive_pattern, content)
    strings.update(matches)
    
    return strings


def read_existing_translations(localizable_path: str) -> Dict[str, str]:
    """Read existing translations from Localizable.strings"""
    translations = {}
    
    if not os.path.exists(localizable_path):
        return translations
    
    with open(localizable_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Pattern: "English" = "Translation";
    pattern = r'"([^"]+)"\s*=\s*"([^"]+)";'
    matches = re.findall(pattern, content)
    
    for english, translation in matches:
        translations[english] = translation
    
    return translations


def write_localizable_file(output_path: str, translations: Dict[str, str], language_code: str):
    """Write translations to Localizable.strings file"""
    
    language_names = {
        "en": "English",
        "de": "German - Deutsch",
        "es": "Spanish - Español",
        "fr": "French - Français"
    }
    
    header = f"""/* 
  Localizable.strings ({language_names.get(language_code, language_code)})
  NoteWall
  
  Auto-generated translations
*/

"""
    
    # Group translations by category
    categories = {
        "Common UI Elements": ["Continue", "Cancel", "Delete", "Done", "Close", "OK", "Skip", "Next", "Yes", "No", "Send", "Apply", "Save"],
        "Loading States": ["Loading...", "Sending...", "Updating…", "Generating...", "Saving…"],
        "Home Screen": ["No notes yet", "Add a note below to get started", "Wallpaper Not Showing?"],
        "Settings": ["Settings", "Wallpaper Settings", "Text Style", "Help & Support"],
        "Onboarding": ["Welcome to NoteWall", "Grant Permissions First", "Start Using NoteWall"],
        "Paywall": ["Unlock Full Access", "Get Premium", "Restore Purchase"],
        "Other": []  # Everything else
    }
    
    categorized = {cat: [] for cat in categories}
    
    for english_text in sorted(translations.keys()):
        assigned = False
        for category, keywords in categories.items():
            if english_text in keywords:
                categorized[category].append(english_text)
                assigned = True
                break
        if not assigned:
            categorized["Other"].append(english_text)
    
    content = header
    
    for category, texts in categorized.items():
        if texts:
            content += f"// MARK: - {category}\n"
            for english_text in texts:
                translated = translations[english_text]
                # Escape quotes in the strings
                english_escaped = english_text.replace('"', '\\"')
                translated_escaped = translated.replace('"', '\\"')
                content += f'"{english_escaped}" = "{translated_escaped}";\n'
            content += "\n"
    
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(content)


def main():
    print("🌍 NoteWall Localization Script")
    print("=" * 50)
    
    # Paths
    notewall_dir = Path("/Users/carly/GITHUB REPOS/STRANKY:APLIKACIE/NOTEWALL-CLAUDECODE/NoteWall")
    
    # Step 1: Extract all hardcoded strings from Swift files
    print("\n📝 Step 1: Extracting hardcoded strings from Swift files...")
    all_strings = set()
    swift_files = list(notewall_dir.glob("*.swift"))
    
    for swift_file in swift_files:
        if swift_file.name not in ["Config.swift"]:  # Skip config
            strings = extract_hardcoded_strings(str(swift_file))
            all_strings.update(strings)
            if strings:
                print(f"   Found {len(strings)} strings in {swift_file.name}")
    
    # Filter out empty strings, numbers, single characters, etc.
    meaningful_strings = {s for s in all_strings if len(s) > 1 and not s.isdigit() and s not in ["", " ", "?", "  "]}
    
    print(f"\n✅ Extracted {len(meaningful_strings)} unique strings")
    
    # Step 2: Check existing translations
    print("\n📚 Step 2: Checking existing translations...")
    en_path = notewall_dir / "en.lproj" / "Localizable.strings"
    existing_en = read_existing_translations(str(en_path))
    print(f"   Found {len(existing_en)} existing English translations")
    
    # Find missing strings
    missing_strings = meaningful_strings - set(existing_en.keys())
    print(f"   Missing {len(missing_strings)} strings from localization")
    
    # Step 3: Build complete translation dictionaries
    print("\n🔤 Step 3: Building translation dictionaries...")
    
    complete_translations = {
        "en": {},
        "de": {},
        "es": {},
        "fr": {}
    }
    
    # Add existing translations
    for string in existing_en:
        complete_translations["en"][string] = existing_en[string]
    
    # Add new strings
    for string in meaningful_strings:
        if string not in complete_translations["en"]:
            complete_translations["en"][string] = string  # English is the same
    
    # Translate to other languages
    for lang_code in ["de", "es", "fr"]:
        lang_existing = read_existing_translations(str(notewall_dir / f"{lang_code}.lproj" / "Localizable.strings"))
        
        for english_text in complete_translations["en"]:
            if english_text in lang_existing:
                # Use existing translation
                complete_translations[lang_code][english_text] = lang_existing[english_text]
            elif english_text in TRANSLATIONS[lang_code]:
                # Use our dictionary
                complete_translations[lang_code][english_text] = TRANSLATIONS[lang_code][english_text]
            else:
                # Keep English as fallback
                complete_translations[lang_code][english_text] = english_text
                print(f"   ⚠️  No translation for '{english_text}' in {lang_code}")
    
    # Step 4: Write updated localization files
    print("\n💾 Step 4: Writing updated localization files...")
    
    for lang_code in ["en", "de", "es", "fr"]:
        output_path = notewall_dir / f"{lang_code}.lproj" / "Localizable.strings"
        write_localizable_file(
            str(output_path),
            complete_translations[lang_code],
            lang_code
        )
        print(f"   ✅ Wrote {len(complete_translations[lang_code])} translations to {lang_code}.lproj")
    
    print("\n" + "=" * 50)
    print("✨ Localization complete!")
    print(f"📊 Total strings: {len(meaningful_strings)}")
    print(f"🌍 Languages: English, German, Spanish, French")
    print("\n💡 Tip: Build and test the app in each language to verify translations")


if __name__ == "__main__":
    main()
